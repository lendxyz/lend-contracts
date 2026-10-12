// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

interface ISafe {
    function nonce() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function domainSeparator() external view returns (bytes32);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);
}

/// @notice Proposes calls from the Lend Safe to the Safe Transaction Service, signed by the broadcaster's Ledger.
/// @dev Call inside `vm.startBroadcast()`; the broadcaster must be a Safe owner and its signature counts as the
///      first confirmation.
///
///      forge cannot sign raw digests with a Ledger (`vm.sign` is unsupported), so the SafeTx is signed as EIP-712
///      typed data through `cast wallet sign --ledger` (FFI). Only one process can hold the Ledger, so the script
///      must NOT be run with `--ledger`; pass the owner with `--sender` and its derivation path in `LEDGER_HD_PATH`:
///
///      LEDGER_HD_PATH="m/44'/60'/0'/0/0" forge script <script> --sender <owner> --rpc-url <rpc> --broadcast
///
///      Without `--broadcast` the transaction is only logged: nothing is signed or proposed.
///      Requires `ffi`, `cast` and `curl`.
library LendMultisig {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address internal constant SAFE = 0xC11f4C91a201461a22EEE735E7EF6f07cdecEcbF;

    bytes32 private constant SAFE_TX_TYPEHASH = keccak256(
        "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    );

    /// @notice Proposes `SAFE` calling `_target` with `_callData` (CALL, no value) at the next free Safe nonce.
    /// @return safeTxHash Hash of the proposed SafeTx.
    function proposeTransaction(address _target, bytes memory _callData) internal returns (bytes32 safeTxHash) {
        (VmSafe.CallerMode callerMode, address sender,) = vm.readCallers();
        require(
            callerMode == VmSafe.CallerMode.Broadcast || callerMode == VmSafe.CallerMode.RecurrentBroadcast,
            "LendMultisig: call inside vm.startBroadcast()"
        );
        require(SAFE.code.length != 0, "LendMultisig: Safe not deployed on this chain");
        require(
            ISafe(SAFE).isOwner(sender),
            string.concat("LendMultisig: broadcaster ", vm.toString(sender), " is not a Safe owner (check --sender)")
        );

        string memory transactionsUrl =
            string.concat(_txServiceUrl(), "/api/v2/safes/", vm.toString(SAFE), "/multisig-transactions/");
        uint256 nonce = _nextNonce(transactionsUrl);

        bytes32 domainSeparator = ISafe(SAFE).domainSeparator();
        bytes32 messageHash = keccak256(
            abi.encode(SAFE_TX_TYPEHASH, _target, 0, keccak256(_callData), 0, 0, 0, 0, address(0), address(0), nonce)
        );
        safeTxHash = keccak256(abi.encodePacked(bytes2(0x1901), domainSeparator, messageHash));
        // The typed data signed below hashes to safeTxHash only if it matches this Safe version's EIP-712 encoding.
        require(
            safeTxHash
                == ISafe(SAFE).getTransactionHash(_target, 0, _callData, 0, 0, 0, 0, address(0), address(0), nonce),
            "LendMultisig: SafeTx encoding does not match the Safe"
        );

        console.log("--- SAFE TRANSACTION PROPOSAL ---");
        console.log("Safe:", SAFE);
        console.log("Proposer:", sender);
        console.log("Target:", _target);
        console.log("Nonce:", nonce);
        console.log("Domain hash:", vm.toString(domainSeparator));
        console.log("Message hash:", vm.toString(messageHash));
        console.log("SafeTx hash:", vm.toString(safeTxHash));

        if (!vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            console.log("Dry run: not signed nor proposed. Rerun with --broadcast to propose.");
            return safeTxHash;
        }

        console.log("Confirm on the Ledger: domain and message hashes must match the ones above.");
        bytes memory signature = _ledgerSign(_typedData(_target, _callData, nonce), safeTxHash, sender);

        string[] memory post = new string[](10);
        post[0] = "curl";
        post[1] = "-sS";
        post[2] = "--fail-with-body";
        post[3] = "-X";
        post[4] = "POST";
        post[5] = "-H";
        post[6] = "Content-Type: application/json";
        post[7] = "-d";
        post[8] = string.concat(
            '{"to":"',
            vm.toString(_target),
            '","value":"0","data":"',
            vm.toString(_callData),
            '","operation":0,"safeTxGas":"0","baseGas":"0","gasPrice":"0","gasToken":"',
            vm.toString(address(0)),
            '","refundReceiver":"',
            vm.toString(address(0)),
            '","nonce":',
            vm.toString(nonce),
            ',"contractTransactionHash":"',
            vm.toString(safeTxHash),
            '","sender":"',
            vm.toString(sender),
            '","signature":"',
            vm.toString(signature),
            '"}'
        );
        post[9] = transactionsUrl;
        _curl(post);

        console.log("Proposed: other owners can now confirm it in the Safe app queue.");
    }

    /// @dev Next nonce after the Safe's executed and queued (proposed, not yet executed) transactions.
    function _nextNonce(string memory transactionsUrl) private returns (uint256 nonce) {
        nonce = ISafe(SAFE).nonce();

        string[] memory get = new string[](4);
        get[0] = "curl";
        get[1] = "-sS";
        get[2] = "--fail-with-body";
        get[3] = string.concat(transactionsUrl, "?ordering=-nonce&limit=1&nonce__gte=", vm.toString(nonce));
        string memory queued = _curl(get);

        if (vm.parseJsonUint(queued, ".count") != 0) {
            nonce = vm.parseJsonUint(queued, ".results[0].nonce") + 1;
        }
    }

    function _ledgerSign(string memory typedData, bytes32 safeTxHash, address sender) private returns (bytes memory) {
        string memory hdPath = vm.envOr("LEDGER_HD_PATH", string(""));
        require(bytes(hdPath).length != 0, "LendMultisig: set LEDGER_HD_PATH to the proposer's Ledger derivation path");

        string[] memory command = new string[](8);
        command[0] = "cast";
        command[1] = "wallet";
        command[2] = "sign";
        command[3] = "--ledger";
        command[4] = "--mnemonic-derivation-path";
        command[5] = hdPath;
        command[6] = "--data";
        command[7] = typedData;

        VmSafe.FfiResult memory result = vm.tryFfi(command);
        require(
            result.exitCode == 0,
            string.concat(
                "LendMultisig: Ledger signing failed (forge must run without --ledger; device unlocked on the Ethereum app): ",
                string(result.stderr)
            )
        );
        // ffi decodes cast's 0x-prefixed hex output into the 65-byte r || s || v signature.
        bytes memory signature = result.stdout;
        require(signature.length == 65, "LendMultisig: unexpected cast signature output");

        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (v < 27) v += 27;

        require(
            ecrecover(safeTxHash, v, r, s) == sender,
            string.concat("LendMultisig: LEDGER_HD_PATH does not derive the broadcaster ", vm.toString(sender))
        );
        return abi.encodePacked(r, s, v);
    }

    function _typedData(address _target, bytes memory _callData, uint256 nonce) private view returns (string memory) {
        return string.concat(
            '{"types":{"EIP712Domain":[{"name":"chainId","type":"uint256"},{"name":"verifyingContract","type":"address"}],',
            '"SafeTx":[{"name":"to","type":"address"},{"name":"value","type":"uint256"},{"name":"data","type":"bytes"},',
            '{"name":"operation","type":"uint8"},{"name":"safeTxGas","type":"uint256"},{"name":"baseGas","type":"uint256"},',
            '{"name":"gasPrice","type":"uint256"},{"name":"gasToken","type":"address"},{"name":"refundReceiver","type":"address"},',
            '{"name":"nonce","type":"uint256"}]},"primaryType":"SafeTx",',
            string.concat(
                '"domain":{"chainId":',
                vm.toString(block.chainid),
                ',"verifyingContract":"',
                vm.toString(SAFE),
                '"},"message":{"to":"',
                vm.toString(_target),
                '","value":0,"data":"',
                vm.toString(_callData),
                '","operation":0,"safeTxGas":0,"baseGas":0,"gasPrice":0,"gasToken":"',
                vm.toString(address(0)),
                '","refundReceiver":"',
                vm.toString(address(0)),
                '","nonce":',
                vm.toString(nonce),
                "}}"
            )
        );
    }

    /// @dev Runs a curl command; reverts with the response body on HTTP errors.
    function _curl(string[] memory command) private returns (string memory) {
        VmSafe.FfiResult memory result = vm.tryFfi(command);
        require(
            result.exitCode == 0,
            string.concat(
                "LendMultisig: Safe Transaction Service request failed: ", string(result.stdout), string(result.stderr)
            )
        );
        return string(result.stdout);
    }

    function _txServiceUrl() private view returns (string memory) {
        string memory network;
        if (block.chainid == 1) network = "eth";
        else if (block.chainid == 56) network = "bnb";
        else if (block.chainid == 137) network = "pol";
        else if (block.chainid == 146) network = "sonic";
        else if (block.chainid == 8453) network = "base";
        else if (block.chainid == 42161) network = "arb1";
        else if (block.chainid == 59144) network = "linea";
        else revert("LendMultisig: no Safe Transaction Service for this chain");

        return string.concat("https://api.safe.global/tx-service/", network);
    }
}
