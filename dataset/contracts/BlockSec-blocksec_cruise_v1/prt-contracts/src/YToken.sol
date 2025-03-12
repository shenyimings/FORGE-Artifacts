// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from  "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from  "@openzeppelin/contracts/access/Ownable.sol";

import { Vault } from "./Vault.sol";

contract YToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    Vault public immutable vault;

    uint256 public cumulativeYieldAcc = 0;
    uint256 public yieldPerTokenAcc = 0;

    struct UserInfo {
        uint256 yieldPerTokenClaimed;
        uint256 accClaimable;
    }
    mapping (address => UserInfo) infos;

    constructor(address vault_,
                string memory name_,
                string memory symbol_) ERC20(name_, symbol_) {

        require(msg.sender == vault_);
        vault = Vault(vault_);
    }

    function trigger() external virtual onlyOwner {
        _checkpointYieldPerToken();
    }

    function isAccumulating() public virtual view returns (bool) {
        return !vault.didTrigger();
    }

    function _checkpointYieldPerToken() internal {
        if (!isAccumulating()) return;
        yieldPerTokenAcc = _yieldPerToken();
        cumulativeYieldAcc = vault.cumulativeYield();
    }

    function _yieldPerToken() internal view returns (uint256) {
        if (totalSupply() == 0) return 0;
        uint256 deltaCumulative = isAccumulating()
            ? vault.cumulativeYield() - cumulativeYieldAcc
            : 0;
        uint256 incr = (deltaCumulative * vault.PRECISION_FACTOR()
                        / totalSupply());
        return yieldPerTokenAcc + incr;
    }

    function claimable(address user) public view returns (uint256) {
        UserInfo storage info = infos[user];
        uint256 ypt = _yieldPerToken() - info.yieldPerTokenClaimed;
        uint256 result = (ypt * balanceOf(user) / vault.PRECISION_FACTOR()
                          + info.accClaimable);
        return result;
    }

    function claim() external {
        UserInfo storage info = infos[msg.sender];
        uint256 amount = claimable(msg.sender);
        if (amount == 0) return;
        vault.disburse(msg.sender, amount);
        info.yieldPerTokenClaimed = _yieldPerToken();
        info.accClaimable = 0;
    }

    function mint(address recipient, uint256 amount) external onlyOwner {
        _checkpointYieldPerToken();
        _mint(recipient, amount);
    }

    function burn(address recipient, uint256 amount) external onlyOwner {
        require(IERC20(address(this)).balanceOf(recipient) >= amount);
        _checkpointYieldPerToken();
        _burn(recipient, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256) internal override {
        uint256 ypt = _yieldPerToken();

        infos[from].accClaimable = claimable(from);
        infos[from].yieldPerTokenClaimed = ypt;
        infos[to].accClaimable = claimable(to);
        infos[to].yieldPerTokenClaimed = ypt;
    }
}
