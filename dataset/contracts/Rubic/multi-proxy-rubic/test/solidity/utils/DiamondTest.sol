// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "rubic/RubicMultiProxy.sol";
import "rubic/Facets/DiamondCutFacet.sol";
import "rubic/Facets/DiamondLoupeFacet.sol";
import "rubic/Facets/OwnershipFacet.sol";
import "rubic/Facets/FeesFacet.sol";
import "rubic/Facets/AccessManagerFacet.sol";
import "rubic/Periphery/ERC20Proxy.sol";
import "rubic/Interfaces/IAccessManagerFacet.sol";
import "rubic/Interfaces/IDiamondCut.sol";

contract DiamondTest {
    IDiamondCut.FacetCut[] internal cut;

    function createDiamond(
        address treasury,
        uint256 maxRubicPlatformFee
    ) internal returns (RubicMultiProxy, address) {
        DiamondCutFacet diamondCut = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupe = new DiamondLoupeFacet();
        OwnershipFacet ownership = new OwnershipFacet();
        AccessManagerFacet access = new AccessManagerFacet();
        FeesFacet fees = new FeesFacet();
        ERC20Proxy erc20proxy = new ERC20Proxy(address(this));
        RubicMultiProxy diamond = new RubicMultiProxy(
            address(this),
            address(diamondCut),
            address(erc20proxy)
        );

        erc20proxy.setAuthorizedCaller(address(diamond), true);

        bytes4[] memory functionSelectors;
        bytes memory initCallData = abi.encodeWithSelector(
            FeesFacet.initialize.selector,
            treasury,
            maxRubicPlatformFee,
            type(uint256).max / 2
        );

        // Diamond Loupe

        functionSelectors = new bytes4[](5);
        functionSelectors[0] = DiamondLoupeFacet
            .facetFunctionSelectors
            .selector;
        functionSelectors[1] = DiamondLoupeFacet.facets.selector;
        functionSelectors[2] = DiamondLoupeFacet.facetAddress.selector;
        functionSelectors[3] = DiamondLoupeFacet.facetAddresses.selector;
        functionSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;
        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(diamondLoupe),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors
            })
        );

        // Ownership Facet

        functionSelectors = new bytes4[](4);
        functionSelectors[0] = OwnershipFacet.transferOwnership.selector;
        functionSelectors[1] = OwnershipFacet.cancelOwnershipTransfer.selector;
        functionSelectors[2] = OwnershipFacet
            .confirmOwnershipTransfer
            .selector;
        functionSelectors[3] = OwnershipFacet.owner.selector;

        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(ownership),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors
            })
        );

        // Fees Facet

        functionSelectors = new bytes4[](5);
        functionSelectors[0] = FeesFacet.setFixedNativeFee.selector;
        functionSelectors[1] = FeesFacet.setRubicPlatformFee.selector;
        functionSelectors[2] = FeesFacet.setIntegratorInfo.selector;
        functionSelectors[3] = FeesFacet.fixedNativeFee.selector;
        functionSelectors[4] = FeesFacet.calcTokenFees.selector;

        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(fees),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors
            })
        );

        // Access Facet

        functionSelectors = new bytes4[](1);
        functionSelectors[0] = AccessManagerFacet.setCanExecute.selector;

        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(access),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors
            })
        );

        DiamondCutFacet(address(diamond)).diamondCut(
            cut,
            address(fees),
            initCallData
        );

        IAccessManagerFacet(address(diamond)).setCanExecute(
            FeesFacet.setFixedNativeFee.selector,
            address(this),
            true
        );

        IAccessManagerFacet(address(diamond)).setCanExecute(
            FeesFacet.setRubicPlatformFee.selector,
            address(this),
            true
        );
        IAccessManagerFacet(address(diamond)).setCanExecute(
            FeesFacet.setIntegratorInfo.selector,
            address(this),
            true
        );

        delete cut;

        return (diamond, address(erc20proxy));
    }

    function addFacet(
        RubicMultiProxy _diamond,
        address _facet,
        bytes4[] memory _selectors
    ) internal {
        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: _facet,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: _selectors
            })
        );

        DiamondCutFacet(address(_diamond)).diamondCut(cut, address(0), "");

        delete cut;
    }
}
