// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/autofarm/IAutoBTC.sol";
import "../interfaces/autofarm/IAutoFarm.sol";
import "../interfaces/autofarm/IStrat.sol";

/**
 * @dev Tokenization V2 of AutoFarm's BTCB position.
 *
 * AutoFarm is currently the biggest yield farming aggregator in BSC, but it's
 * yield position is not tokenized so that AutoFarm users cannot enhance capital
 * efficiency of their positions.
 *
 * The purpose of AutoBTC is to tokenized AutoFarm's BTCB position so that:
 * 1. The total supply of autoBTC equals the total shares owned by autoBTC in the BTCB strategy;
 * 2. User's autoBTC balance equals the share they could get by depositing the same
 * amount of BTCB into AutoFarm directly;
 * 3. Users won't lose any AUTO rewards by minting autoBTC.
 * 
 * The interface of autoBTC and autoBTCv2 is unchanged. Only the strategy address and PID are changed.
 */
contract AutoBTCv2 is ERC20Upgradeable, IAutoBTC {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    event Minted(address indexed account, uint256 amount, uint256 mintAmount);
    event Redeemed(address indexed account, uint256 amount, uint256 redeemAmount);
    event Claimed(address indexed account, uint256 amount);

    address public constant BTCB = address(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    address public constant AUTOv2 = address(0xa184088a740c695E156F91f5cC086a06bb78b827);
    address public constant AUTOFARM = address(0x0895196562C7868C5Be92459FaE7f877ED450452);
    // Only strategy and PID are changed in autoBTCv2
    address public constant BTBC_STRAT = address(0xA8c50e9F552886612109fE27CB94111A2F8006DE);
    uint256 public constant PID = 0x59;
    uint256 public constant WAD = 10**18;

    // Accumulated AUTO per token in WAD
    uint256 public rewardPerTokenStored;
    // Auto balance of this contract in the last update
    uint256 public lastReward;
    // User address => Reward debt per token for this user
    mapping(address => uint256) public rewardPerTokenPaid;
    // User address => Claimable rewards for this user
    mapping(address => uint256) public rewards;

    /**
     * @dev Initializes the autoBTC.
     */
    function initialize() public initializer {
        // BTCB and AutoFarm BTCB share are both 18 decimals.
        __ERC20_init("AutoFarm BTC v2", "autoBTCv2");
        // We set infinite allowance since autoBTC does not hold any asset.
        IERC20Upgradeable(BTCB).safeApprove(AUTOFARM, uint256(int256(-1)));
    }

    /**
     * @dev Returns the current exchange rate between AutoBTC and BTCB.
     */
    function exchangeRate() public view override returns (uint256) {
        return totalSupply() == 0 ? WAD : IAutoFarm(AUTOFARM).stakedWantTokens(PID, address(this)).mul(WAD).div(totalSupply());
    }

    /**
     * @dev Updates rewards for the user.
     */
    function _updateReward(address _account) internal {
        uint256 _totalSupply = totalSupply();
        uint256 _reward = IERC20Upgradeable(AUTOv2).balanceOf(address(this));
        uint256 _rewardDiff = _reward.sub(lastReward);

        if (_totalSupply > 0 && _rewardDiff > 0) {
            lastReward = _reward;
            rewardPerTokenStored = _rewardDiff.mul(WAD).div(_totalSupply).add(rewardPerTokenStored);
        }

        rewards[_account] = rewardPerTokenStored.sub(rewardPerTokenPaid[_account])
            .mul(balanceOf(_account)).div(WAD).add(rewards[_account]);
        rewardPerTokenPaid[_account] = rewardPerTokenStored;
    }

    /**
     * @dev Mints autoBTC with BTCB.
     * @param _amount Amount of BTCB used to mint autoBTC.
     */
    function mint(uint256 _amount) public override {
        uint256 _before = IStrat(BTBC_STRAT).sharesTotal();
        IERC20Upgradeable(BTCB).safeTransferFrom(msg.sender, address(this), _amount);

        // Note: AutoFarm has an entrance fee
        // Each deposit and withdraw trigger AUTO distribution in AutoFarm
        IAutoFarm(AUTOFARM).deposit(PID, _amount);
        uint256 _after = IStrat(BTBC_STRAT).sharesTotal();

        // Updates the rewards before minting
        _updateReward(msg.sender);

        // 1 autoBTC = 1 share in AutoFarm BTCB strategy
        _mint(msg.sender, _after.sub(_before));

        emit Minted(msg.sender, _amount, _after.sub(_before));
    }

    /**
     * @dev Redeems autoBTC to BTCB.
     * @param _amount Amount of autoBTC to redeem.
     */
    function redeem(uint256 _amount) public override {
        uint256 _btcbTotal = IStrat(BTBC_STRAT).wantLockedTotal();
        uint256 _shareTotal = IStrat(BTBC_STRAT).sharesTotal();
        uint256 _btcb = _amount.mul(_btcbTotal).div(_shareTotal);

        // Each deposit and withdraw trigger AUTO distribution in AutoFarm
        IAutoFarm(AUTOFARM).withdraw(PID, _btcb);

        // Updates the rewards before redeeming
        _updateReward(msg.sender);

        // 1 autoBTC = 1 share in AutoFarm BTCB strategy
        _burn(msg.sender, _amount);

        _btcb = IERC20Upgradeable(BTCB).balanceOf(address(this));
        IERC20Upgradeable(BTCB).safeTransfer(msg.sender, _btcb);

        emit Redeemed(msg.sender, _btcb, _amount);
    }

    /**
     * @dev Returns the pending AUTO to the account.
     */
    function pendingReward(address _account) public view override returns (uint256) {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0)  return 0;

        uint256 _pendingReward = IAutoFarm(AUTOFARM).pendingAUTO(PID, address(this));
        uint256 _rewardPerToken = _pendingReward.mul(WAD).div(_totalSupply).add(rewardPerTokenStored);
        return _rewardPerToken.sub(rewardPerTokenPaid[_account]).mul(balanceOf(_account)).div(WAD)
            .add(rewards[_account]);
    }

    /**
     * @dev Claims all AUTO available for the caller.
     */
    function claimRewards() public override {
        // Triggers AUTO distribution with a zero deposit
        IAutoFarm(AUTOFARM).deposit(PID, 0);

        // Updates the rewards before redeeming
        _updateReward(msg.sender);

        uint256 _reward = rewards[msg.sender];
        if (_reward > 0) {
            IERC20Upgradeable(AUTOv2).safeTransfer(msg.sender, _reward);
            rewards[msg.sender] = 0;
        }

        // Need to update the reward balance again!
        lastReward = IERC20Upgradeable(AUTOv2).balanceOf(address(this));

        emit Claimed(msg.sender, _reward);
    }

    /**
     * @dev Updates AUTO rewards before actual transfer.
     */
    function _transfer(address _from, address _to, uint256 _amount) internal virtual override {
        // Triggers AUTO distribution with a zero deposit
        IAutoFarm(AUTOFARM).deposit(PID, 0);

        // Updates the rewards before the actual transfer
        _updateReward(_from);
        _updateReward(_to);

        super._transfer(_from, _to, _amount);
    }
}