// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IRouter {
    type MakerTraits is uint256;
    type TakerTraits is uint256;
    type Address is uint256;

    struct Order {
        uint256 salt;
        Address maker;
        Address receiver;
        Address makerAsset;
        Address takerAsset;
        uint256 makingAmount;
        uint256 takingAmount;
        MakerTraits makerTraits;
    }

    function fillOrder(Order calldata order, bytes32 r, bytes32 vs, uint256 amount, TakerTraits takerTraits)
        external
        payable
        returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash);
}

contract OneInchAdapter is Ownable, IRouter {
    error UnsupportedOperation();
    error BatchParamettersMissmatch();
    error BatchExecutionFailed();

    address public routerAddress;

    constructor(address _admin, address _router) Ownable(_admin) {
        routerAddress = _router;
    }

    receive() external payable {
        revert UnsupportedOperation();
    }

    fallback() external payable {
        address ra = routerAddress;

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), ra, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function batchFillOrder(
        Order[] calldata orders,
        bytes32[] calldata rComponents,
        bytes32[] calldata vsComponents,
        uint256[] calldata amounts,
        TakerTraits[] calldata takerTraitsList
    )
        external
        payable
        returns (uint256[] memory makingAmounts, uint256[] memory takingAmounts, bytes32[] memory orderHashs)
    {
        require(orders.length == rComponents.length, BatchParamettersMissmatch());
        require(orders.length == vsComponents.length, BatchParamettersMissmatch());
        require(orders.length == amounts.length, BatchParamettersMissmatch());
        require(orders.length == takerTraitsList.length, BatchParamettersMissmatch());

        makingAmounts = new uint256[](orders.length);
        takingAmounts = new uint256[](orders.length);
        orderHashs = new bytes32[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            (bool success, bytes memory data) = routerAddress.delegatecall(
                abi.encodeWithSelector(
                    IRouter.fillOrder.selector,
                    orders[i],
                    rComponents[i],
                    vsComponents[i],
                    amounts[i],
                    takerTraitsList[i]
                )
            );

            require(success, BatchExecutionFailed());

            (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash) =
                abi.decode(data, (uint256, uint256, bytes32));

            makingAmounts[i] = makingAmount;
            takingAmounts[i] = takingAmount;
            orderHashs[i] = orderHash;
        }
    }

    function fillOrder(Order calldata order, bytes32 r, bytes32 vs, uint256 amount, TakerTraits takerTraits)
        external
        payable
        returns (uint256 makingAmount, uint256 takingAmount, bytes32 orderHash)
    {
        (bool success, bytes memory data) = routerAddress.delegatecall(
            abi.encodeWithSelector(IRouter.fillOrder.selector, order, r, vs, amount, takerTraits)
        );

        require(success, BatchExecutionFailed());

        (makingAmount, takingAmount, orderHash) = abi.decode(data, (uint256, uint256, bytes32));
    }

    function updateRouter(address newRouter) public onlyOwner {
        uint32 size;
        assembly {
            size := extcodesize(newRouter)
        }

        require(size > 0, "Router needs to be a smart contract");

        routerAddress = newRouter;
    }
}
