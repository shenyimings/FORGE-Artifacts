// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../../staking/IStaking.sol";
import "./IPropsTokenL2.sol";
import "./IRPropsToken.sol";

/**
 * @title  RPropsToken
 * @author Props
 * @dev    The rProps token represents future Props rewards. Its role is to get
 *         distributed to the app and user Props staking contracts and have the
 *         rewards in those contracts be earned in rProps. The rProps token is
 *         then swappable for regular Props tokens. This acts as a workaround
 *         for having to mint Props tokens before actual distribution to users.
 */
contract RPropsToken is Initializable, ERC20Upgradeable, IRPropsToken {
    using SafeMathUpgradeable for uint256;

    /**************************************
                     FIELDS
    ***************************************/

    // The rProps token controller
    address public controller;

    // Props protocol related tokens
    address public propsToken;

    // The staking contract for earning apps Props rewards
    address public propsAppStaking;
    // The staking contract for earning users Props rewards
    address public propsUserStaking;

    /**************************************
                    MODIFIERS
    ***************************************/

    modifier only(address _account) {
        require(msg.sender == _account, "Unauthorized");
        _;
    }

    modifier notSet(address _field) {
        require(_field == address(0), "Already set");
        _;
    }

    /***************************************
                   INITIALIZER
    ****************************************/

    /**
     * @dev Initializer.
     * @param _controller The rProps token controller
     * @param _propsToken The address of the Props token contract
     */
    function initialize(address _controller, address _propsToken) public initializer {
        ERC20Upgradeable.__ERC20_init("rProps", "RPROPS");

        controller = _controller;
        propsToken = _propsToken;
    }

    /***************************************
                CONTROLLER ACTIONS
    ****************************************/

    /**
     * @dev Set the staking contract for earning apps Props rewards.
     * @param _propsAppStaking The address of the staking contract for earning apps Props rewards
     */
    function setPropsAppStaking(address _propsAppStaking)
        external
        override
        only(controller)
        notSet(propsAppStaking)
    {
        propsAppStaking = _propsAppStaking;
    }

    /**
     * @dev Set the staking contract for earning users Props rewards.
     * @param _propsUserStaking The address of the staking contract for earning users Props rewards.
     */
    function setPropsUserStaking(address _propsUserStaking)
        external
        override
        only(controller)
        notSet(propsUserStaking)
    {
        propsUserStaking = _propsUserStaking;
    }

    /**
     * @dev Distribute rProps rewards to the app and user Props staking contracts.
     *      This action mints the given amount of rProps and calls the rewards
     *      distribution action on the staking contracts.
     * @param _amount The amount of rProps to mint and distribute
     * @param _appRewardsPercentage The percentage of minted rProps to get distributed to apps (in ppm)
     * @param _userRewardsPercentage The percentage of minted rProps to get distributed to users (in ppm)
     */
    function distributeRewards(
        uint256 _amount,
        uint256 _appRewardsPercentage,
        uint256 _userRewardsPercentage
    ) external override only(controller) {
        // The percentages must add up to 100%
        require(_appRewardsPercentage.add(_userRewardsPercentage) == 1e6, "Invalid percentages");

        // Distribute app rProps rewards
        uint256 appRewards = _amount.mul(_appRewardsPercentage).div(1e6);
        _mint(propsAppStaking, appRewards);
        IStaking(propsAppStaking).notifyRewardAmount(appRewards);

        // Distribute user rProps rewards
        uint256 userRewards = _amount.sub(appRewards);
        _mint(propsUserStaking, userRewards);
        IStaking(propsUserStaking).notifyRewardAmount(userRewards);
    }

    /**
     * @dev Withdraw rProps rewards from the app and user Props staking contracts.
     * @param _appRewardsAmount The amount of rProps to get withdrawn from the app Props staking contract
     * @param _userRewardsAmount The amount of rProps to get withdrawn from the user Props staking contract
     */
    function withdrawRewards(uint256 _appRewardsAmount, uint256 _userRewardsAmount)
        external
        override
        only(controller)
    {
        // Withdraw and burn app rProps rewards
        IStaking(propsAppStaking).withdrawReward(_appRewardsAmount);
        _burn(address(this), _appRewardsAmount);

        // Withdraw user rProps rewards
        IStaking(propsUserStaking).withdrawReward(_userRewardsAmount);
        _burn(address(this), _userRewardsAmount);
    }

    /**
     * @dev Change the daily reward emission parameter on the app Props staking contract.
     * @param _appDailyRewardEmission The new daily reward emission rate
     */
    function changeDailyAppRewardEmission(uint256 _appDailyRewardEmission)
        external
        override
        only(controller)
    {
        IStaking(propsAppStaking).changeDailyRewardEmission(_appDailyRewardEmission);
    }

    /**
     * @dev Change the daily reward emission parameter on the user Props staking contract.
     * @param _userDailyRewardEmission The new daily reward emission rate
     */
    function changeDailyUserRewardEmission(uint256 _userDailyRewardEmission)
        external
        override
        only(controller)
    {
        IStaking(propsUserStaking).changeDailyRewardEmission(_userDailyRewardEmission);
    }

    /**
     * @dev Swap an account's rProps balance for regular Props.
     * @param _account The swap recipient
     */
    function swap(address _account) external override only(controller) {
        uint256 amount = balanceOf(_account);
        if (amount > 0) {
            // Burn rProps
            _burn(_account, amount);

            // Mint Props
            IPropsTokenL2(propsToken).mint(_account, amount);
        }
    }
}
