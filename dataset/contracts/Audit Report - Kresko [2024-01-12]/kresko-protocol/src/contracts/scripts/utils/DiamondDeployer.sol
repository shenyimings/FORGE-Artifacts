// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
import {FacetCut, FacetCutAction, Initializer} from "diamond/DSTypes.sol";
import {Diamond} from "diamond/Diamond.sol";
error InitializerMismatch(uint256 initializerCount, uint256 initializerArgsCount);
error SelectorBytecodeMismatch(uint256 selectorCount, uint256 bytecodeCount);

contract DiamondDeployer {
    function create(
        address owner,
        bytes[] calldata facets,
        bytes4[][] calldata functions,
        uint256[] calldata initializers,
        bytes[] calldata datas
    ) public returns (Diamond) {
        (FacetCut[] memory cuts, Initializer[] memory inits) = createFacets(facets, functions, initializers, datas);
        return new Diamond(owner, cuts, inits);
    }

    function createFacets(
        bytes[] calldata facets,
        bytes4[][] calldata selectors,
        uint256[] calldata initCodeIndexes,
        bytes[] calldata initDatas
    ) public returns (FacetCut[] memory cuts, Initializer[] memory initializers) {
        if (facets.length != selectors.length) {
            revert SelectorBytecodeMismatch(selectors.length, facets.length);
        }
        if (initCodeIndexes.length != initDatas.length) {
            revert InitializerMismatch(initCodeIndexes.length, initDatas.length);
        }
        cuts = new FacetCut[](facets.length);
        initializers = new Initializer[](initDatas.length);
        for (uint256 i; i < facets.length; ) {
            cuts[i].action = FacetCutAction.Add;
            cuts[i].facetAddress = deploy(facets[i]);
            cuts[i].functionSelectors = selectors[i];
            unchecked {
                i++;
            }
        }
        for (uint256 i; i < initDatas.length; ) {
            initializers[i].initContract = cuts[initCodeIndexes[i]].facetAddress;
            initializers[i].initData = initDatas[i];
            unchecked {
                i++;
            }
        }
    }

    function deploy(bytes memory bytecode) public returns (address location) {
        assembly {
            location := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }
}
