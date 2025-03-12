//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../modules/admin/Authorization.sol";
import "../../interfaces/IYESVault.sol";
import "../../interfaces/IYESController.sol";

contract Releaser is Authorization {
    uint256 public releaseRate;
    uint256 public maxElapse;
    address public vault;
    address public controller;
    mapping(address => uint256) public lastRelease;

    event SetReleaseRate(uint256 oldReleaseRate, uint256 newReleaseRate);
    event SetMaxElapse(uint256 oldMaxElapse, uint256 newMaxElapse);
    event SetVault(address oldVault, address newVault);
    event SetController(address oldController, address newController);
    event Release(address user, uint256 releaseAmount);

    constructor(
        uint256 releaseRate_,
        uint256 maxElapse_,
        address vault_,
        address controller_,
        address adminRouter_
    ) Authorization(adminRouter_) {
        setReleaseRate(releaseRate_);
        setMaxElapse(maxElapse_);
        setController(controller_);
        setVault(vault_);
    }

    function getCurrentRelease(address user) public view returns (uint256) {
        uint256 actualElapse = block.timestamp - lastRelease[user];
        uint256 elapse = actualElapse <= maxElapse ? actualElapse : maxElapse;
        return (elapse * releaseRate) / maxElapse;
    }

    function release(address user) public {
        require(
            msg.sender == user || adminRouter.isSuperAdmin(msg.sender, PROJECT),
            "Require self release or super admin"
        );
        require(
            IYESController(controller).borrowLimitOf(user) > 0,
            "Require KYC"
        );
        uint256 releaseAmount = getCurrentRelease(user);
        IYESVault(vault).airdrop(user, releaseAmount);
        lastRelease[user] = block.timestamp;
        emit Release(user, releaseAmount);
    }

    function setReleaseRate(uint256 _releaseRate) public onlyAdmin {
        uint256 oldReleaseRate = releaseRate;
        releaseRate = _releaseRate;
        emit SetReleaseRate(oldReleaseRate, releaseRate);
    }

    function setMaxElapse(uint256 _maxElapse) public onlyAdmin {
        uint256 oldMaxElapse = maxElapse;
        maxElapse = _maxElapse;
        emit SetMaxElapse(oldMaxElapse, maxElapse);
    }

    function setVault(address _vault) public onlyAdmin {
        address oldVault = vault;
        vault = _vault;
        emit SetVault(oldVault, vault);
    }

    function setController(address _controller) public onlyAdmin {
        address oldController = controller;
        controller = _controller;
        emit SetController(oldController, controller);
    }
}
