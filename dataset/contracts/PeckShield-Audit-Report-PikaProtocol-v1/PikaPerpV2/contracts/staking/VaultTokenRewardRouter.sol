// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../staking/IVaultReward.sol';
import "../access/Governable.sol";

// Router that allows two different tokens to distribute to vault depositors. Each token is handled by one VaultTokenReward contract.
// PikaPerp contract's vaultTokenReward will be set to this router contract.
contract VaultTokenRewardRouter is Governable {

    address public vaultTokenReward1;
    address public vaultTokenReward2;
    address public admin;

    event SetVaultTokenRewards(address vaultTokenReward1, address vaultTokenReward2);
    event SetAdmin(address admin);

    constructor(address _vaultTokenReward1, address _vaultTokenReward2) public {
        vaultTokenReward1 = _vaultTokenReward1;
        vaultTokenReward2 = _vaultTokenReward2;
        admin = msg.sender;
    }

    function updateReward(address account) public {
        IVaultReward(vaultTokenReward1).updateReward(account);
        IVaultReward(vaultTokenReward2).updateReward(account);
    }

    function setVaultTokenRewards(address _vaultTokenReward1, address _vaultTokenReward2) public onlyAdmin {
        vaultTokenReward1 = _vaultTokenReward1;
        vaultTokenReward2 = _vaultTokenReward2;
        emit SetVaultTokenRewards(_vaultTokenReward1, _vaultTokenReward2);
    }

    function setAdmin(address _admin) external onlyGov {
        admin = _admin;
        emit SetAdmin(_admin);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "VaultTokenRewardRouter: forbidden");
        _;
    }
}
