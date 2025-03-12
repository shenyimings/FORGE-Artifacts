// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./IPropsProtocol.sol";
import "./tokens/props/IPropsTokenL2.sol";
import "./tokens/props/IRPropsToken.sol";
import "./tokens/props/ISPropsToken.sol";
import "./staking/IStaking.sol";
import "./utils/MetaTransactionProvider.sol";

/**
 * @title  PropsProtocol
 * @author Props
 * @notice Entry point for participating in the Props protocol. All user actions
 *         are to be done exclusively through this contract.
 * @dev    It is responsible for proxying staking-related actions to the appropriate
 *         staking contracts. Moreover, it also handles sProps minting and burning,
 *         sProps staking, swapping earned rProps for regular Props and escrowing
 *         user Props rewards.
 */
contract PropsProtocol is
    Initializable,
    PausableUpgradeable,
    MetaTransactionProvider,
    IPropsProtocol
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**************************************
                     FIELDS
    ***************************************/

    // The Props protocol controller
    address public controller;

    // The Props protocol guardian (has the ability to pause/unpause the protocol)
    address public guardian;

    // Props protocol related tokens
    address public propsToken;
    address public sPropsToken;
    address public rPropsToken;

    // The factory contract for deploying new apps
    address public appProxyFactory;

    // The staking contract for earning apps Props rewards
    address public propsAppStaking;
    // The staking contract for earning users Props rewards
    address public propsUserStaking;

    // Mapping from app points contract to the associated app points staking contract
    mapping(address => address) public appPointsStaking;

    // Mapping of the total amount of Props principal staked by each user to every app
    // eg. stakes[userAddress][appPointsAddress]
    mapping(address => mapping(address => uint256)) public stakes;
    // Mapping of the total amount of Props rewards staked by each user to every app
    // eg. rewardStakes[userAddress][appPointsAddress]
    mapping(address => mapping(address => uint256)) public rewardStakes;
    // Mapping of the total amount of Props staked to each app
    // eg. appStakes[appPointsAddress]
    mapping(address => uint256) public appStakes;

    // Keeps track of the staking delegatees of users
    mapping(address => address) public delegates;

    // Mapping of the total amount of escrowed rewards of each user
    mapping(address => uint256) public rewardsEscrow;
    // Mapping of the unlock time for the escrowed rewards of each user
    mapping(address => uint256) public rewardsEscrowUnlock;

    // The cooldown period for the rewards escrow (in seconds)
    uint256 public rewardsEscrowCooldown;

    // Keeps track of the protocol-whitelisted apps
    mapping(address => bool) private appWhitelist;

    /**************************************
                     EVENTS
    ***************************************/

    event Staked(address indexed app, address indexed account, int256 amount, bool rewards);
    event RewardsEscrowUpdated(address indexed account, uint256 lockedAmount, uint256 unlockTime);
    event PropsRewardsClaimed(address indexed account, uint256 amount, bool app);
    event AppPointsRewardsClaimed(address indexed app, address indexed account, uint256 amount);
    event AppWhitelistUpdated(address indexed app, bool status);
    event DelegateChanged(address indexed delegator, address indexed delegatee);

    /**************************************
                    MODIFIERS
    ***************************************/

    modifier only(address _account) {
        require(_msgSender() == _account, "Unauthorized");
        _;
    }

    modifier notSet(address _field) {
        require(_field == address(0), "Already set");
        _;
    }

    modifier validApp(address _app) {
        require(appPointsStaking[_app] != address(0), "Invalid app");
        _;
    }

    /***************************************
                   INITIALIZER
    ****************************************/

    /**
     * @dev Initializer.
     * @param _controller The Props protocol controller
     * @param _guardian The Props protocol guardian
     * @param _propsToken The Props token contract
     */
    function initialize(
        address _controller,
        address _guardian,
        address _propsToken
    ) public initializer {
        PausableUpgradeable.__Pausable_init();
        MetaTransactionProvider.__MetaTransactionProvider_init("PropsProtocol", "1");

        controller = _controller;
        guardian = _guardian;
        propsToken = _propsToken;
        rewardsEscrowCooldown = 90 days;
    }

    /***************************************
                GUARDIAN ACTIONS
    ****************************************/

    /**
     * @dev Pause the protocol.
     */
    function pause() external {
        require(_msgSender() == controller || _msgSender() == guardian, "Unauthorized");
        _pause();
    }

    /**
     * @dev Unpause the protocol.
     */
    function unpause() external {
        require(_msgSender() == controller || _msgSender() == guardian, "Unauthorized");
        _unpause();
    }

    /***************************************
                CONTROLLER ACTIONS
    ****************************************/

    /**
     * @dev Transfer the control of the contract to a new address.
     * @param _controller The new controller
     */
    function transferControl(address _controller) external only(controller) {
        require(_controller != address(0), "Cannot be set to the zero address");
        controller = _controller;
    }

    /**
     * @dev Transfer the guardian role to a new address.
     * @param _guardian The new guardian
     */
    function transferGuardianship(address _guardian) external only(controller) {
        require(_guardian != address(0), "Cannot be set to the zero address");
        guardian = _guardian;
    }

    /*
     * The following set methods are required to be called before any contract interaction:
     * - setAppProxyFactory
     * - setRPropsToken
     * - setSPropsToken
     * - setPropsAppStaking
     * - setPropsUserStaking
     *
     * ! `setRPropsToken` must be called before `setPropsAppStaking` and `setPropsUserStaking` !
     */

    /**
     * @dev Set the app proxy factory contract.
     * @param _appProxyFactory The address of the app proxy factory contract
     */
    function setAppProxyFactory(address _appProxyFactory)
        external
        only(controller)
        notSet(appProxyFactory)
    {
        appProxyFactory = _appProxyFactory;
    }

    /**
     * @dev Set the rProps token contract.
     * @param _rPropsToken The address of the rProps token contract
     */
    function setRPropsToken(address _rPropsToken) external only(controller) notSet(rPropsToken) {
        rPropsToken = _rPropsToken;
    }

    /**
     * @dev Set the sProps token contract.
     * @param _sPropsToken The address of the sProps token contract
     */
    function setSPropsToken(address _sPropsToken) external only(controller) notSet(sPropsToken) {
        sPropsToken = _sPropsToken;
    }

    /**
     * @dev Set the staking contract for earning apps Props rewards.
     * @param _propsAppStaking The address of the staking contract for earning apps Props rewards
     */
    function setPropsAppStaking(address _propsAppStaking)
        external
        only(controller)
        notSet(propsAppStaking)
    {
        propsAppStaking = _propsAppStaking;
        IRPropsToken(rPropsToken).setPropsAppStaking(_propsAppStaking);
    }

    /**
     * @dev Set the staking contract for earning users Props rewards.
     * @param _propsUserStaking The address of the staking contract for earning users Props rewards.
     */
    function setPropsUserStaking(address _propsUserStaking)
        external
        only(controller)
        notSet(propsUserStaking)
    {
        propsUserStaking = _propsUserStaking;
        IRPropsToken(rPropsToken).setPropsUserStaking(_propsUserStaking);
    }

    /**
     * @dev Change the cooldown period for the escrowed rewards.
     * @param _rewardsEscrowCooldown The cooldown period for the escrowed rewards
     */
    function changeRewardsEscrowCooldown(uint256 _rewardsEscrowCooldown) external only(controller) {
        rewardsEscrowCooldown = _rewardsEscrowCooldown;
    }

    /**
     * @dev Update the app whitelist.
     * @param _app The address of the app to update the whitelist status of
     * @param _status The whitelist status of the app
     */
    function updateAppWhitelist(address _app, bool _status) external only(controller) {
        require(appWhitelist[_app] != _status, "Invalid status");

        if (appStakes[_app] > 0) {
            if (_status == true) {
                // On whitelisting, re-stake all sProps previously staked to the app
                IStaking(propsAppStaking).stake(_app, appStakes[_app]);
            } else {
                // On blacklisting, withdraw all sProps staked to the app
                IStaking(propsAppStaking).withdraw(_app, appStakes[_app]);
            }
        }

        appWhitelist[_app] = _status;
        emit AppWhitelistUpdated(_app, _status);
    }

    /**
     * @dev Distribute the rProps rewards to the app and user Props staking contracts.
     * @param _amount The amount of rProps to mint and get distributed as staking rewards
     * @param _appRewardsPercentage The percentage of minted rProps to go to the app Props staking contract
     * @param _userRewardsPercentage The percentage of minted rProps to go to the user Props staking contract
     */
    function distributePropsRewards(
        uint256 _amount,
        uint256 _appRewardsPercentage,
        uint256 _userRewardsPercentage
    ) external only(controller) {
        IRPropsToken(rPropsToken).distributeRewards(
            _amount,
            _appRewardsPercentage,
            _userRewardsPercentage
        );
    }

    /**
     * @dev Withdraw rProps rewards from the app and user staking contracts.
     * @param _appRewardsAmount The amount of rProps rewards to withdraw from the app Props staking contract
     * @param _userRewardsAmount The amount of rProps rewards to withdraw from the user Props staking contract
     */
    function withdrawPropsRewards(uint256 _appRewardsAmount, uint256 _userRewardsAmount)
        external
        only(controller)
    {
        IRPropsToken(rPropsToken).withdrawRewards(_appRewardsAmount, _userRewardsAmount);
    }

    /**
     * @dev Change the daily reward emission parameter on the app Props staking contract.
     * @param _appDailyRewardEmission The new daily reward emission rate
     */
    function changeDailyAppRewardEmission(uint256 _appDailyRewardEmission)
        external
        only(controller)
    {
        IRPropsToken(rPropsToken).changeDailyAppRewardEmission(_appDailyRewardEmission);
    }

    /**
     * @dev Change the daily reward emission parameter on the user Props staking contract.
     * @param _userDailyRewardEmission The new daily reward emission rate
     */
    function changeDailyUserRewardEmission(uint256 _userDailyRewardEmission)
        external
        only(controller)
    {
        IRPropsToken(rPropsToken).changeDailyUserRewardEmission(_userDailyRewardEmission);
    }

    /***************************************
               APP FACTORY ACTIONS
    ****************************************/

    /**
     * @dev Save identification information for a newly deployed app.
     * @param _appPoints The address of the app points contract
     * @param _appPointsStaking The address of the app points staking contract
     */
    function saveApp(address _appPoints, address _appPointsStaking)
        external
        override
        only(appProxyFactory)
    {
        appPointsStaking[_appPoints] = _appPointsStaking;
    }

    /***************************************
                  USER ACTIONS
    ****************************************/

    /**
     * @dev Delegate staking rights.
     * @param _to The account to delegate to
     */
    function delegate(address _to) external whenNotPaused {
        delegates[_msgSender()] = _to;
        emit DelegateChanged(_msgSender(), _to);
    }

    /**
     * @dev Stake on behalf of an account. It makes it possible to easily
     *      transfer a staking portofolio to someone else. The staked Props
     *      are transferred from the sender's account but staked on behalf of
     *      the requested account.
     * @param _apps Array of apps to stake to
     * @param _amounts Array of amounts to stake to each app
     * @param _account Account to stake on behalf of
     */
    function stakeOnBehalf(
        address[] memory _apps,
        uint256[] memory _amounts,
        address _account
    ) public whenNotPaused {
        // Convert from uint256 to int256
        int256[] memory amounts = new int256[](_amounts.length);
        for (uint256 i = 0; i < _amounts.length; i++) {
            amounts[i] = _safeInt256(_amounts[i]);
        }

        _stake(_apps, amounts, _msgSender(), _account, false);
    }

    /**
     * @dev Same as `stakeOnBehalf`, but uses a permit for approving Props transfers.
     */
    function stakeOnBehalfWithPermit(
        address[] calldata _apps,
        uint256[] calldata _amounts,
        address _account,
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external whenNotPaused {
        IPropsTokenL2(propsToken).permit(_owner, _spender, _amount, _deadline, _v, _r, _s);
        stakeOnBehalf(_apps, _amounts, _account);
    }

    /**
     * @dev Stake/unstake to/from apps. This function is used for both staking
     *      and unstaking to/from apps. It accepts both positive and negative
     *      amounts, which represent an adjustment of the staked amount to the
     *      corresponding app.
     * @param _apps Array of apps to stake/unstake to/from
     * @param _amounts Array of amounts to stake/unstake to/from each app
     */
    function stake(address[] memory _apps, int256[] memory _amounts) public whenNotPaused {
        _stake(_apps, _amounts, _msgSender(), _msgSender(), false);
    }

    /**
     * @dev Same as `stake`, but uses a permit for approving Props transfers.
     */
    function stakeWithPermit(
        address[] calldata _apps,
        int256[] calldata _amounts,
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external whenNotPaused {
        IPropsTokenL2(propsToken).permit(_owner, _spender, _amount, _deadline, _v, _r, _s);
        stake(_apps, _amounts);
    }

    /**
     * @dev Stake on behalf of a delegator. The delegatee can only readjust
     *      existing stake (eg. unstaking amount X from an app and staking
     *      back the same amount X to another app) but not add or remove any
     *      other stake (the call will fail in such cases).
     * @param _apps Array of app tokens to stake/unstake to/from
     * @param _amounts Array of amounts to stake/unstake to/from each app token
     * @param _account Delegator account to stake on behalf of
     */
    function stakeAsDelegate(
        address[] calldata _apps,
        int256[] calldata _amounts,
        address _account
    ) external only(delegates[_account]) whenNotPaused {
        _stake(_apps, _amounts, _account, _account, false);
    }

    /**
     * @dev Similar to a regular stake operation, this function is used to
     *      stake/unstake to/from apps. The only difference is that it uses
     *      the escrowed rewards instead of transferring from the user's wallet.
     * @param _apps Array of apps to stake/unstake to/from
     * @param _amounts Array of amounts to stake/unstake to/from each app
     */
    function stakeRewards(address[] memory _apps, int256[] memory _amounts) public whenNotPaused {
        _stake(_apps, _amounts, _msgSender(), _msgSender(), true);
    }

    /**
     * @dev Stake rewards on behalf of a delegator. While the delegatee can
     *      introduce additional stake from the delegator's escrow, it cannot
     *      trigger any withdraws (which would increase the delegator's escrow
     *      unlock time).
     * @param _apps Array of apps to stake/unstake to/from
     * @param _amounts Array of amounts to stake/unstake to/from each app
     * @param _account Delegator account to stake on behalf of
     */
    function stakeRewardsAsDelegate(
        address[] memory _apps,
        int256[] memory _amounts,
        address _account
    ) public only(delegates[_account]) whenNotPaused {
        _stake(_apps, _amounts, _account, _account, true);
    }

    /**
     * @dev Allow users to claim their app points rewards.
     * @param _apps Array of apps to claim the app points rewards of
     */
    function claimAppPointsRewards(address[] memory _apps) external whenNotPaused {
        for (uint256 i = 0; i < _apps.length; i++) {
            require(appPointsStaking[_apps[i]] != address(0), "Invalid app");

            // Claim the rewards and transfer them to the user's wallet
            uint256 reward = IStaking(appPointsStaking[_apps[i]]).earned(_msgSender());
            if (reward > 0) {
                IStaking(appPointsStaking[_apps[i]]).claimReward(_msgSender());
                IERC20Upgradeable(_apps[i]).safeTransfer(_msgSender(), reward);

                emit AppPointsRewardsClaimed(_apps[i], _msgSender(), reward);
            }
        }
    }

    /**
     * @dev Allow app owners to claim their app's Props rewards.
     * @param _app The app to claim the Props rewards of
     * @param _wallet The address claimed Props rewards are to be withdrawn to
     */
    function claimAppPropsRewards(address _app, address _wallet)
        external
        validApp(_app)
        only(OwnableUpgradeable(_app).owner())
        whenNotPaused
    {
        // Claim the rewards and transfer them to the user's wallet
        uint256 reward = IStaking(propsAppStaking).earned(_app);
        if (reward > 0) {
            IStaking(propsAppStaking).claimReward(_app);
            IERC20Upgradeable(rPropsToken).safeTransfer(_wallet, reward);
            // Since the rewards are in rProps, swap it for regular Props
            IRPropsToken(rPropsToken).swap(_wallet);

            emit PropsRewardsClaimed(_app, reward, true);
        }
    }

    /**
     * @dev Allow app owners to claim and directly stake their app's Props rewards.
     * @param _app The app to claim and stake the Props rewards of
     */
    function claimAppPropsRewardsAndStake(address _app)
        external
        validApp(_app)
        only(OwnableUpgradeable(_app).owner())
        whenNotPaused
    {
        uint256 reward = IStaking(propsAppStaking).earned(_app);
        if (reward > 0) {
            IStaking(propsAppStaking).claimReward(_app);
            // Since the rewards are in rProps, swap it for regular Props
            IRPropsToken(rPropsToken).swap(address(this));

            emit PropsRewardsClaimed(_app, reward, true);

            address[] memory _apps = new address[](1);
            _apps[0] = _app;
            int256[] memory _amounts = new int256[](1);
            _amounts[0] = _safeInt256(reward);

            _stake(_apps, _amounts, address(this), _msgSender(), false);
        }
    }

    /**
     * @dev Allow users to claim their Props rewards.
     */
    function claimUserPropsRewards() external whenNotPaused {
        uint256 reward = IStaking(propsUserStaking).earned(_msgSender());
        if (reward > 0) {
            // Claim the rewards but don't transfer them to the user's wallet
            IStaking(propsUserStaking).claimReward(_msgSender());
            // Since the rewards are in rProps, swap it for regular Props
            IRPropsToken(rPropsToken).swap(address(this));

            emit PropsRewardsClaimed(_msgSender(), reward, false);

            // Place the rewards in the escrow and extend the cooldown period
            rewardsEscrow[_msgSender()] = rewardsEscrow[_msgSender()].add(reward);
            rewardsEscrowUnlock[_msgSender()] = block.timestamp.add(rewardsEscrowCooldown);

            emit RewardsEscrowUpdated(
                _msgSender(),
                rewardsEscrow[_msgSender()],
                rewardsEscrowUnlock[_msgSender()]
            );
        }
    }

    /**
     * @dev Allow users to claim and directly stake their Props rewards, without
     *      having the rewards go through the escrow (and thus having the unlock
     *      time of the escrow extended).
     * @param _apps Array of apps to stake to
     * @param _percentages Array of percentages of the claimed rewards to stake to each app (in ppm)
     */
    function claimUserPropsRewardsAndStake(
        address[] calldata _apps,
        uint256[] calldata _percentages
    ) external whenNotPaused {
        _claimUserPropsRewardsAndStake(_apps, _percentages, _msgSender());
    }

    /**
     * @dev Claim and stake user Props rewards on behalf of a delegator.
     * @param _apps Array of apps to stake to
     * @param _percentages Array of percentages of the claimed rewards to stake to each app (in ppm)
     * @param _account Delegator account to claim and stake on behalf of
     */
    function claimUserPropsRewardsAndStakeAsDelegate(
        address[] calldata _apps,
        uint256[] calldata _percentages,
        address _account
    ) external only(delegates[_account]) whenNotPaused {
        _claimUserPropsRewardsAndStake(_apps, _percentages, _account);
    }

    /**
     * @dev Allow users to unlock their escrowed Props rewards.
     */
    function unlockUserPropsRewards() external whenNotPaused {
        require(block.timestamp >= rewardsEscrowUnlock[_msgSender()], "Rewards locked");

        if (rewardsEscrow[_msgSender()] > 0) {
            // Empty the escrow
            uint256 escrowedRewards = rewardsEscrow[_msgSender()];
            rewardsEscrow[_msgSender()] = 0;

            // Transfer the rewards to the user's wallet
            IERC20Upgradeable(propsToken).safeTransfer(_msgSender(), escrowedRewards);

            emit RewardsEscrowUpdated(_msgSender(), 0, 0);
        }
    }

    /***************************************
                     HELPERS
    ****************************************/

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, MetaTransactionProvider)
        returns (address payable)
    {
        // Allow `permitAndCall` calls from the Props token contract
        if (msg.sender == propsToken) {
            return _extractMsgSender();
        }
        return MetaTransactionProvider._msgSender();
    }

    function _stake(
        address[] memory _apps,
        int256[] memory _amounts,
        // Where should the stake funds come from?
        address _from,
        // Where should the stakes go to?
        address _to,
        bool _rewards
    ) internal {
        require(_apps.length == _amounts.length, "Invalid input");

        // First, handle all unstakes (negative amounts)
        uint256 totalUnstakedAmount = 0;
        for (uint256 i = 0; i < _apps.length; i++) {
            require(appPointsStaking[_apps[i]] != address(0), "Invalid app");

            if (_amounts[i] < 0) {
                uint256 amountToUnstake = uint256(SignedSafeMathUpgradeable.mul(_amounts[i], -1));

                // Update user total staked amounts
                if (_rewards) {
                    rewardStakes[_to][_apps[i]] = rewardStakes[_to][_apps[i]].sub(amountToUnstake);
                } else {
                    stakes[_to][_apps[i]] = stakes[_to][_apps[i]].sub(amountToUnstake);
                }

                // Update app total staked amount
                appStakes[_apps[i]] = appStakes[_apps[i]].sub(amountToUnstake);

                // Unstake the Props from the app points staking contract
                IStaking(appPointsStaking[_apps[i]]).withdraw(_to, amountToUnstake);

                // Unstake the sProps from the app Props staking contract
                if (appWhitelist[_apps[i]]) {
                    // The sProps are only staked in the app Props staking contract if the app is whitelisted
                    IStaking(propsAppStaking).withdraw(_apps[i], amountToUnstake);
                }

                // Don't unstake the sProps from the user Props staking contract since some
                // of them might get re-staked when handling the positive amounts (only unstake
                // the left amount at the end)

                // Update the total unstaked amount
                totalUnstakedAmount = totalUnstakedAmount.add(amountToUnstake);

                emit Staked(_apps[i], _to, _amounts[i], _rewards);
            }
        }

        // Handle all stakes (positive amounts)
        for (uint256 i = 0; i < _apps.length; i++) {
            if (_amounts[i] > 0) {
                require(appWhitelist[_apps[i]], "App not whitelisted");

                uint256 amountToStake = uint256(_amounts[i]);

                // Update user total staked amounts
                if (_rewards) {
                    rewardStakes[_to][_apps[i]] = rewardStakes[_to][_apps[i]].add(amountToStake);
                } else {
                    stakes[_to][_apps[i]] = stakes[_to][_apps[i]].add(amountToStake);
                }

                // Update app total staked amount
                appStakes[_apps[i]] = appStakes[_apps[i]].add(amountToStake);

                if (totalUnstakedAmount >= amountToStake) {
                    // If the previously unstaked amount can cover the stake then use that
                    totalUnstakedAmount = totalUnstakedAmount.sub(amountToStake);
                } else {
                    uint256 left = amountToStake.sub(totalUnstakedAmount);

                    if (_rewards) {
                        // Otherwise, if we are handling the rewards, get the needed Props from escrow
                        rewardsEscrow[_from] = rewardsEscrow[_from].sub(left);

                        emit RewardsEscrowUpdated(
                            _from,
                            rewardsEscrow[_from],
                            rewardsEscrowUnlock[_from]
                        );
                    } else if (_from != address(this)) {
                        // When acting on behalf of a delegator no transfers are allowed
                        require(_msgSender() == _from, "Unauthorized");

                        // Otherwise, if we are handling the principal, transfer the needed Props
                        IERC20Upgradeable(propsToken).safeTransferFrom(_from, address(this), left);
                    }

                    // Mint corresponding sProps
                    ISPropsToken(sPropsToken).mint(_to, left);

                    // Also stake the corresponding sProps in the user Props staking contract
                    IStaking(propsUserStaking).stake(_to, left);

                    totalUnstakedAmount = 0;
                }

                // Stake the Props in the app points staking contract
                IStaking(appPointsStaking[_apps[i]]).stake(_to, amountToStake);

                // Stake the sProps in the app Props staking contract
                IStaking(propsAppStaking).stake(_apps[i], amountToStake);

                emit Staked(_apps[i], _to, _amounts[i], _rewards);
            }
        }

        // If more tokens were unstaked than staked
        if (totalUnstakedAmount > 0) {
            // When acting on behalf of a delegator no withdraws are allowed
            require(_msgSender() == _from, "Unauthorized");

            // Unstake the corresponding sProps from the user Props staking contract
            IStaking(propsUserStaking).withdraw(_to, totalUnstakedAmount);

            if (_rewards) {
                rewardsEscrow[_to] = rewardsEscrow[_to].add(totalUnstakedAmount);
                rewardsEscrowUnlock[_to] = block.timestamp.add(rewardsEscrowCooldown);

                emit RewardsEscrowUpdated(_to, rewardsEscrow[_to], rewardsEscrowUnlock[_to]);
            } else {
                // Transfer any left Props back to the user
                IERC20Upgradeable(propsToken).safeTransfer(_to, totalUnstakedAmount);
            }

            // Burn the sProps
            ISPropsToken(sPropsToken).burn(_to, totalUnstakedAmount);
        }
    }

    function _claimUserPropsRewardsAndStake(
        address[] memory _apps,
        uint256[] memory _percentages,
        address _account
    ) internal {
        require(_apps.length == _percentages.length, "Invalid input");

        uint256 reward = IStaking(propsUserStaking).earned(_account);
        if (reward > 0) {
            // Claim the rewards but don't transfer them to the user's wallet
            IStaking(propsUserStaking).claimReward(_account);
            // Since the rewards are in rProps, swap it for regular Props
            IRPropsToken(rPropsToken).swap(address(this));

            emit PropsRewardsClaimed(_account, reward, false);

            // Place the rewards in the escrow but don't extend the cooldown period
            rewardsEscrow[_account] = rewardsEscrow[_account].add(reward);

            // Calculate amounts from the given percentages
            uint256 totalPercentage = 0;
            uint256 totalAmountSoFar = 0;
            int256[] memory amounts = new int256[](_percentages.length);
            for (uint256 i = 0; i < _percentages.length; i++) {
                if (i < _percentages.length.sub(1)) {
                    amounts[i] = _safeInt256(reward.mul(_percentages[i]).div(1e6));
                } else {
                    // Make sure nothing gets lost
                    amounts[i] = _safeInt256(reward.sub(totalAmountSoFar));
                }

                totalPercentage = totalPercentage.add(_percentages[i]);
                totalAmountSoFar = totalAmountSoFar.add(uint256(amounts[i]));
            }
            // The given percentages must add up to 100%
            require(totalPercentage == 1e6, "Invalid percentages");

            if (_account == _msgSender()) {
                stakeRewards(_apps, amounts);
            } else {
                stakeRewardsAsDelegate(_apps, amounts, _account);
            }
        }
    }

    function _safeInt256(uint256 a) internal pure returns (int256) {
        require(a <= 2**255 - 1, "Overflow");
        return int256(a);
    }
}
