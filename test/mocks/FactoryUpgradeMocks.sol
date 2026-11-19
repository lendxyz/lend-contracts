// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AppStorage, LibAppStorage} from "src/Factory/lib/Storage.sol";
import {LibDiamond} from "src/Factory/lib/LibDiamond.sol";
import {Admin} from "src/Factory/facets/Admin.sol";
import {Getters} from "src/Factory/facets/Getters.sol";

/// @dev Admin plus a new function: Replace of the Admin selectors, Add of `upgradeProbe`.
contract AdminAddMock is Admin {
    function upgradeProbe() external pure returns (uint256) {
        return 42;
    }
}

/// @dev Same functions as Getters, other executable code: Replace of the Getters selectors.
contract GettersReplaceMock is Getters {
    fallback() external {
        revert("GettersReplaceMock");
    }
}

/// @dev Ownership without `transferOwnership`: Replace of `owner`, Remove of `transferOwnership`.
contract OwnershipRemoveMock {
    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.diamondStorage().contractOwner;
    }
}

/// @dev Ownership reading the owner from the wrong storage: same functions, corrupted output.
contract OwnershipMisreadMock {
    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view returns (address owner_) {
        owner_ = LibAppStorage.appStorage().backendSigner;
    }
}

/// @dev Upgrade inits, delegatecalled by the diamond after the cut.
contract FactoryUpgradeInitMock {
    function setEurc(address eurc) external {
        LibAppStorage.appStorage().eurc = IERC20(eurc);
    }

    function resetOperationCount() external {
        LibAppStorage.appStorage().operationCount = 0;
    }

    function blacklistAccount(address account) external {
        LibAppStorage.appStorage().blacklisted[account] = true;
    }

    function setOperationShares(uint256 opId, uint256 totalShares) external {
        LibAppStorage.appStorage().operations[opId].totalShares = totalShares;
    }

    function setOwner(address newOwner) external {
        LibDiamond.diamondStorage().contractOwner = newOwner;
    }

    function approveUsdc(address spender) external {
        LibAppStorage.appStorage().usdc.approve(spender, 1);
    }

    function revertingInit() external pure {
        revert("init failed");
    }

    /// @dev Writes then restores a slot, like a reentrancy lock: no net change.
    function lockAndRelease() external {
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 status = s.reentrancyStatus;
        s.reentrancyStatus = 2;
        s.reentrancyStatus = status;
    }
}
