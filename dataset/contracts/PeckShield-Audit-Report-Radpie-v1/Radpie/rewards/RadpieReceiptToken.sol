// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)
pragma solidity ^0.8.19;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IMasterRadpie.sol";
import "../interfaces/IRadiantStaking.sol";

/// @title RadpieReceiptToken is to represent a Radiant Asset deposited back to Radiant. RadpieReceiptToken is minted to user who deposited Asset token
///        on Radiant again DLP Tokens again on Radidant increase defi lego
///
///         Reward from Magpie and on BaseReward should be updated upon every transfer.
///
/// @author Magpie Team
/// @notice Master Radpie emit `RDP` reward token based on Time. For a pool,

contract RadpieReceiptToken is ERC20, Ownable {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;

    address public underlying;
    address public immutable masterRadpie;
    address public immutable radiantStaking;
    uint256 public constant WAD = 10 ** 18;
    uint8 public immutable setDecimal;

    constructor(
        uint8 _decimals,
        address _underlying,
        address _radiantStaking,
        address _masterRadpie,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        underlying = _underlying;
        masterRadpie = _masterRadpie;
        setDecimal = _decimals;
        radiantStaking = _radiantStaking;
    }

    function decimals() public view override returns (uint8) {
        return setDecimal;
    }

    /// @dev ratio of receipt token to underlying asset. Calculated by All collateral minus debt.
    /// return in WAD
    function assetPerShare() external view returns(uint256) {
        if (radiantStaking == address(0))
            return WAD;

        (,address rToken, address vdToken,,,,,,) = IRadiantStaking(radiantStaking).pools(underlying);

        uint256 reciptTokenTotal = this.totalSupply();
        uint256 rTokenBal = IERC20(rToken).balanceOf(address(radiantStaking));
        
        if (reciptTokenTotal == 0 || rTokenBal == 0) return WAD;

        uint256 vdTokenBal = IERC20(vdToken).balanceOf(address(radiantStaking));

        return ((rTokenBal - vdTokenBal) * WAD) / reciptTokenTotal;        
    }

    // should only be called by 1. RadiantStaking for Radiant Asset deposits 2. masterRadpie for other general staking token such as mDLP or Radpie DLp tokens
    function mint(address account, uint256 amount) external virtual onlyOwner {
        _mint(account, amount);
    }

    // should only be called by 1. RadiantStaking for Radiant Asset deposits 2. masterRadpie for other general staking token such as mDLP or Radpie DLp tokens
    function burn(address account, uint256 amount) external virtual onlyOwner {
        _burn(account, amount);
    }

    // rewards are calculated based on user's receipt token balance, so reward should be updated on master Radpie before transfer
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        IMasterRadpie(masterRadpie).beforeReceiptTokenTransfer(from, to, amount);
    }

    // rewards are calculated based on user's receipt token balance, so balance should be updated on master Radpie before transfer
    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        IMasterRadpie(masterRadpie).afterReceiptTokenTransfer(from, to, amount);
    }
}
