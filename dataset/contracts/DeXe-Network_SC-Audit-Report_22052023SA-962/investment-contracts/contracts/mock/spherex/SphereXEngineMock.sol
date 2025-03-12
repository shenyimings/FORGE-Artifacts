// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@spherex-xyz/contracts/src/ISphereXEngine.sol";

contract SphereXEngineMock is ISphereXEngine {
    bool public shouldRevert;

    function toggleRevert() external {
        shouldRevert = !shouldRevert;
    }

    function sphereXValidatePre(
        int256,
        address,
        bytes calldata
    ) external view override returns (bytes32[] memory returnData) {
        _revert();

        return returnData;
    }

    function sphereXValidatePost(
        int256,
        uint256,
        bytes32[] calldata,
        bytes32[] calldata
    ) external view override {
        _revert();
    }

    function sphereXValidateInternalPre(
        int256
    ) external view returns (bytes32[] memory returnData) {
        _revert();

        return returnData;
    }

    function sphereXValidateInternalPost(
        int256,
        uint256,
        bytes32[] calldata,
        bytes32[] calldata
    ) external view {
        _revert();
    }

    function addAllowedSenderOnChain(address sender) external override {}

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    function _revert() internal view {
        require(!shouldRevert, "SphereXEngineMock: malicious tx");
    }
}
