// SPDX-License-Identifier: MIT
//
//         ++++++++++++++++++++++
//        ++++++++++++++++++++++++
//        ++++++++++++++++++++++++++++++++
//        +++++++++               +++++++++
//         ++++++++++++++++++++++++++++++++
//                 ++++++++++++++++++++++++
//                  ++++++++++++++++++++++
//
//  +++++++                                      ++++
//  +++++++                                      ++++
//    +++++       +++            +++        ++   ++++
//    +++++   ++++++++++  +++++++++++++  ++++++++++++
//    +++++  +++++   ++++++++++++++++++++++++++++++++
//    +++++  ++++++++++++++++++    +++++++++     ++++
//    +++++  +++++        ++++     +++++++++    +++++
//   +++++++++++++++++++++++++     ++++++++++++++++++
//   +++++++++ +++++++++  ++++     +++++ ++++++++++++
//

pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "./interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "./lib/LibDiamond.sol";
import {AppStorage, LibAppStorage} from "./lib/Storage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Diamond is IDiamondCut, IDiamondLoupe, Ownable {
    error UnsupportedOperation();

    constructor(
        address _admin,
        address _usdcAddress,
        address _eurUsdOracle,
        address _lzEndpoint,
        address _backendSigner
    ) Ownable(_admin) {
        AppStorage storage s = LibAppStorage.appStorage();
        s.USDC = IERC20(_usdcAddress);
        s.eurUsdOracle = _eurUsdOracle;
        s.LZ_ENDPOINT = _lzEndpoint;
        s.backendSigner = _backendSigner;
        s.operationCount = 0;
    }

    receive() external payable {
        revert UnsupportedOperation();
    }

    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }

    // Diamond Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct Facet {
    //     address facetAddress;
    //     bytes4[] functionSelectors;
    // }

    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet)
        external
        view
        override
        returns (bytes4[] memory facetFunctionSelectors_)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetFunctionSelectors_ = ds.facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddresses_ = ds.facetAddresses;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddress_ = ds.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }
}
