// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9;

import "script/utils/DeploymentHelpers.sol";

contract SmartDeploy is DeploymentHelpers {
    function smartDeploy(
        bool deployNewDiamond,
        bool initNewDiamond,
        FacetDeploymentAction facetDeploymentAction,
        string[] memory facetsToCutIn
    )
        external
        returns (
            // string[] memory facetsToCutIn
            address diamondAddress,
            address initDiamondAddress
        )
    {
        vm.startBroadcast(msg.sender);

        (diamondAddress, initDiamondAddress) = smartDeployment(deployNewDiamond, initNewDiamond, facetDeploymentAction, facetsToCutIn);

        vm.stopBroadcast();
    }
}
