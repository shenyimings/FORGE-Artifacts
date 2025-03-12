// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IPlus.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IGaugeController.sol";

/**
 * @title Controller for all liquidity gauges.
 *
 * The Gauge Controller is responsible for the following:
 * 1) AC emission rate computation for plus gauges;
 * 2) AC reward claiming;
 * 3) Liquidity gauge withdraw fee processing.
 *
 * Liquidity gauges can be divided into two categories:
 * 1) Plus gauge: Liquidity gauges for plus tokens, the total rate is dependent on the total staked amount in these gauges;
 * 2) Non-plus gage: Liquidity gauges for non-plus token, the rate is set by governance.
 */
contract GaugeController is Initializable, IGaugeController {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    event GovernanceUpdated(address indexed oldGovernance, address indexed newGovernance);
    event ClaimerUpdated(address indexed claimer, bool allowed);
    event BasePlusRateUpdated(uint256 oldBaseRate, uint256 newBaseRate);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event GaugeAdded(address indexed gauge, bool plus, uint256 gaugeWeight, uint256 gaugeRate);
    event GaugeRemoved(address indexed gauge);
    event GaugeUpdated(address indexed gauge, uint256 oldWeight, uint256 newWeight, uint256 oldGaugeRate, uint256 newGaugeRate);
    event Checkpointed(uint256 oldRate, uint256 newRate, uint256 totalSupply, uint256 ratePerToken, address[] gauges, uint256[] guageRates);
    event RewardClaimed(address indexed gauge, address indexed user, address indexed receiver, uint256 amount);
    event FeeProcessed(address indexed gauge, address indexed token, uint256 amount);

    uint256 constant WAD = 10 ** 18;
    uint256 constant LOG_10_2 = 301029995663981195;  // log10(2) = 0.301029995663981195
    uint256 constant DAY = 86400;
    uint256 constant PLUS_BOOST_THRESHOLD = 100 * WAD;   // Plus boosting starts at 100 plus staked!

    address public override governance;
    // AC token
    address public override reward;
    // Address => Whether this is claimer address.
    // A claimer can help claim reward on behalf of the user.
    mapping(address => bool) public override claimers;
    address public override treasury;

    struct Gauge {
        // Helps to check whether the gauge is in the gauges list.
        bool isSupported;
        // Whether this is a plus gauge. The emission rate for the plus gauges depends on
        // the total staked value in the plus gauges, while the emission rate for the non-plus
        // gauges is set by the governance.
        bool isPlus;
        // Multiplier applied to the gauge in computing emission rate. Only applied to plus
        // gauges as non-plus gauges should have fixed rate set by governance.
        uint256 weight;
        // Fixed AC emission rate for non-plus gauges.
        uint256 rate;
    }

    // List of supported liquidity gauges
    address[] public gauges;
    // Liquidity gauge address => Liquidity gauge data
    mapping(address => Gauge) public gaugeData;
    // Liquidity gauge address => Actual AC emission rate
    // For non-plus gauges, it is equal to gaugeData.rate when staked amount is non-zero and zero otherwise.
    mapping(address => uint256) public override gaugeRates;

    // Base AC emission rate for plus gauges. It's equal to the emission rate when there is no plus boosting,
    // i.e. total plus staked <= PLUS_BOOST_THRESHOLD
    uint256 public basePlusRate;
    // Boost for all plus gauges. 1 when there is no plus boosting, i.e.total plus staked <= PLUS_BOOST_THRESHOLD
    uint256 public plusBoost;
    // Global AC emission rate, including both plus and non-plus gauge.
    uint256 public totalRate;
    // Last time the checkpoint is called
    uint256 public lastCheckpoint;
    // Total amount of AC rewarded until the latest checkpoint
    uint256 public lastTotalReward;
    // Total amount of AC claimed so far. totalReward - totalClaimed is the minimum AC balance that should be kept.
    uint256 public totalClaimed;
    // Mapping: Gauge address => Mapping: User address => Total claimed amount for this user in this gauge
    mapping(address => mapping(address => uint256)) public override claimed;
    // Mapping: User address => Timestamp of the last claim
    mapping(address => uint256) public override lastClaim;

    /**
     * @dev Initializes the gauge controller.
     * @param _reward AC token address.
     * @param _plusRewardPerDay Amount of AC rewarded per day for plus gauges if there is no plus boost.
     */
    function initialize(address _reward, uint256 _plusRewardPerDay) public initializer {        
        governance = msg.sender;
        treasury = msg.sender;
        reward = _reward;
        // Base rate is in WAD
        basePlusRate = _plusRewardPerDay.mul(WAD).div(DAY);
        plusBoost = WAD;
        lastCheckpoint = block.timestamp;
    }

    /**
     * @dev Computes log2(num). Result in WAD.
     * Credit: https://medium.com/coinmonks/math-in-solidity-part-5-exponent-and-logarithm-9aef8515136e
     */
    function _log2(uint256 num) internal pure returns (uint256) {
        uint256 msb = 0;
        uint256 xc = num;
        if (xc >= 0x100000000000000000000000000000000) { xc >>= 128; msb += 128; }    // 2**128
        if (xc >= 0x10000000000000000) { xc >>= 64; msb += 64; }
        if (xc >= 0x100000000) { xc >>= 32; msb += 32; }
        if (xc >= 0x10000) { xc >>= 16; msb += 16; }
        if (xc >= 0x100) { xc >>= 8; msb += 8; }
        if (xc >= 0x10) { xc >>= 4; msb += 4; }
        if (xc >= 0x4) { xc >>= 2; msb += 2; }
        if (xc >= 0x2) msb += 1;  // No need to shift xc anymore
    
        uint256 lsb = 0;
        uint256 ux = num << uint256 (127 - msb);
        for (uint256 bit = 0x8000000000000000; bit > 0; bit >>= 1) {
          ux *= ux;
          uint256 b = ux >> 255;
          ux >>= 127 + b;
          lsb += bit * b;
        }
    
        return msb * 10**18 + (lsb * 10**18 >> 64);
    }

    /**
     * @dev Computes log10(num). Result in WAD.
     * Credit: https://medium.com/coinmonks/math-in-solidity-part-5-exponent-and-logarithm-9aef8515136e
     */
    function _log10(uint256 num) internal pure returns (uint256) {
        return _log2(num).mul(LOG_10_2).div(WAD);
    }

    /**
     * @dev Most important function of the gauge controller. Recompute total AC emission rate
     * as well as AC emission rate per liquidity guage.
     * Anyone can call this function so that if the liquidity gauge is exploited by users with short-term
     * large amount of minting, others can restore to the correct mining paramters.
     */
    function checkpoint() public {
        // Loads the gauge list for better performance
        address[] memory _gauges = gauges;
        // The total amount of plus tokens staked
        uint256 _totalPlus = 0;
        // The total weighted amount of plus tokens staked
        uint256 _totalWeightedPlus = 0;
        // Amount of plus token staked in each gauge
        uint256[] memory _gaugePlus = new uint256[](_gauges.length);
        // Weighted amount of plus token staked in each gauge
        uint256[] memory _gaugeWeightedPlus = new uint256[](_gauges.length);
        uint256 _plusBoost = WAD;

        for (uint256 i = 0; i < _gauges.length; i++) {
            // Don't count if it's non-plus gauge
            if (!gaugeData[_gauges[i]].isPlus) continue;

            // Liquidity gauge token and staked token is 1:1
            // Total plus is used to compute boost
            address _staked = IGauge(_gauges[i]).token();
            // Rebase once to get an accurate result
            IPlus(_staked).rebase();
            _gaugePlus[i] = IGauge(_gauges[i]).totalStaked();
            _totalPlus = _totalPlus.add(_gaugePlus[i]);

            // Weighted plus is used to compute rate allocation
            _gaugeWeightedPlus[i] = _gaugePlus[i].mul(gaugeData[_gauges[i]].weight);
            _totalWeightedPlus = _totalWeightedPlus.add(_gaugeWeightedPlus[i]);
        }

        // Computes the AC emission per plus. The AC emission rate is determined by total weighted plus staked.
        uint256 _ratePerPlus = 0;
        // Total AC emission rate for plus gauges is zero if the weighted total plus staked is zero!
        if (_totalWeightedPlus > 0) {
            // Plus boost is applied when more than 100 plus are staked
            if (_totalPlus > PLUS_BOOST_THRESHOLD) {
                // rate = baseRate * (log total - 1)
                // Minus 19 since the TVL is in WAD, so -1 - 18 = -19
                _plusBoost = _log10(_totalPlus) - 19 * WAD;
            }

            // Both plus boot and total weighted plus are in WAD so it cancels out
            // Therefore, _ratePerPlus is still in WAD
            _ratePerPlus = basePlusRate.mul(_plusBoost).div(_totalWeightedPlus);
        }

        // Allocates AC emission rates for each liquidity gauge
        uint256 _oldTotalRate = totalRate;
        uint256 _totalRate;
        uint256[] memory _gaugeRates = new uint256[](_gauges.length);
        for (uint256 i = 0; i < _gauges.length; i++) {
            if (gaugeData[_gauges[i]].isPlus) {
                // gauge weighted plus is in WAD
                // _ratePerPlus is also in WAD
                // so block.timestamp gauge rate is in WAD
                _gaugeRates[i] = _gaugeWeightedPlus[i].mul(_ratePerPlus).div(WAD);
            } else {
                // AC emission rate for non-plus gauge is fixed and set by the governance.
                // However, if no token is staked, the gauge rate is zero.
                _gaugeRates[i] = IERC20Upgradeable(_gauges[i]).totalSupply() == 0 ? 0 : gaugeData[_gauges[i]].rate;
            }
            gaugeRates[_gauges[i]] = _gaugeRates[i];
            _totalRate = _totalRate.add(_gaugeRates[i]);
        }

        // Checkpoints gauge controller
        lastTotalReward = lastTotalReward.add(_oldTotalRate.mul(block.timestamp.sub(lastCheckpoint)).div(WAD));
        lastCheckpoint = block.timestamp;
        totalRate = _totalRate;
        plusBoost = _plusBoost;

        // Checkpoints each gauge to consume the latest rate
        // We trigger gauge checkpoint after all parameters are updated
        for (uint256 i = 0; i < _gauges.length; i++) {
            IGauge(_gauges[i]).checkpoint();
        }

        emit Checkpointed(_oldTotalRate, _totalRate, _totalPlus, _ratePerPlus, _gauges, _gaugeRates);
    }

    /**
     * @dev Claims rewards for a user. Only the liquidity gauge can call this function.
     * @param _account Address of the user to claim reward.
     * @param _receiver Address that receives the claimed reward
     * @param _amount Amount of AC to claim
     */
    function claim(address _account, address _receiver, uint256 _amount) external override {
        require(gaugeData[msg.sender].isSupported, "not gauge");

        totalClaimed = totalClaimed.add(_amount);
        claimed[msg.sender][_account] = claimed[msg.sender][_account].add(_amount);
        lastClaim[msg.sender] = block.timestamp;
        IERC20Upgradeable(reward).safeTransfer(_receiver, _amount);

        emit RewardClaimed(msg.sender, _account, _receiver, _amount);
    }

    /**
     * @dev Return the total amount of rewards generated so far.
     */
    function totalReward() public view returns (uint256) {
        return lastTotalReward.add(totalRate.mul(block.timestamp.sub(lastCheckpoint)).div(WAD));
    }

    /**
     * @dev Returns the total amount of rewards that can be claimed by user until block.timestamp.
     * It can be seen as minimum amount of reward tokens should be buffered in the gauge controller.
     */
    function claimable() external view returns (uint256) {
        return totalReward().sub(totalClaimed);
    }

    /**
     * @dev Returns the total number of gauges.
     */
    function gaugeSize() public view returns (uint256) {
        return gauges.length;
    }

    /**
     * @dev Donate the gauge fee. Only liqudity gauge can call this function.
     * @param _token Address of the donated token.
     */
    function donate(address _token) external override {
        require(gaugeData[msg.sender].isSupported, "not gauge");

        uint256 _balance = IERC20Upgradeable(_token).balanceOf(address(this));
        if (_balance == 0)  return;
        address _staked = IGauge(msg.sender).token();

        if (gaugeData[msg.sender].isPlus && _token == _staked) {
            // If this is a plus gauge and the donated token is the gauge staked token,
            // then the gauge is donating the plus token!
            // For plus token, donate it to all holders
            IPlus(_token).donate(_balance);
        } else {
            // Otherwise, send to treasury for future process
            IERC20Upgradeable(_token).safeTransfer(treasury, _balance);
        }
    }

    /*********************************************
     *
     *    Governance methods
     *
     **********************************************/
    
    function _checkGovernance() internal view {
        require(msg.sender == governance, "not governance");
    }

    modifier onlyGovernance() {
        _checkGovernance();
        _;
    }

    /**
     * @dev Updates governance. Only governance can update governance.
     */
    function setGovernance(address _governance) external onlyGovernance {
        address _oldGovernance = governance;
        governance = _governance;
        emit GovernanceUpdated(_oldGovernance, _governance);
    }

    /**
     * @dev Updates claimer. Only governance can update claimers.
     */
    function setClaimer(address _account, bool _allowed) external onlyGovernance {
        claimers[_account] = _allowed;
        emit ClaimerUpdated(_account, _allowed);
    }

    /**
     * @dev Updates the AC emission base rate for plus gauges. Only governance can update the base rate.
     */
    function setPlusReward(uint256 _plusRewardPerDay) external onlyGovernance {
        uint256 _oldRate = basePlusRate;
        // Base rate is in WAD
        basePlusRate = _plusRewardPerDay.mul(WAD).div(DAY);
        // Need to checkpoint with the base rate update!
        checkpoint();

        emit BasePlusRateUpdated(_oldRate, basePlusRate);
    }

    /**
     * @dev Updates the treasury.
     */
    function setTreasury(address _treasury) external onlyGovernance {
        require(_treasury != address(0x0), "treasury not set");
        address _oldTreasury = treasury;
        treasury = _treasury;

        emit TreasuryUpdated(_oldTreasury, _treasury);
    }

    /**
     * @dev Adds a new liquidity gauge to the gauge controller. Only governance can add new gauge.
     * @param _gauge The new liquidity gauge to add.
     * @param _plus Whether it's a plus gauge.
     * @param _weight Weight of the liquidity gauge. Useful for plus gauges only.
     * @param _rewardPerDay AC reward for the gauge per day. Useful for non-plus gauges only.
     */
    function addGauge(address _gauge, bool _plus, uint256 _weight, uint256 _rewardPerDay) external onlyGovernance {
        require(_gauge != address(0x0), "gauge not set");
        require(!gaugeData[_gauge].isSupported, "gauge exist");

        uint256 _rate = _rewardPerDay.mul(WAD).div(DAY);
        gauges.push(_gauge);
        gaugeData[_gauge] = Gauge({
            isSupported: true,
            isPlus: _plus,
            weight: _weight,
            // Reward rate is in WAD
            rate: _rate
        });

        // Need to checkpoint with the new token!
        checkpoint();

        emit GaugeAdded(_gauge, _plus, _weight, _rate);
    }

    /**
     * @dev Removes a liquidity gauge from gauge controller. Only governance can remove a plus token.
     * @param _gauge The liquidity gauge to remove from gauge controller.
     */
    function removeGauge(address _gauge) external onlyGovernance {
        require(_gauge != address(0x0), "gauge not set");
        require(gaugeData[_gauge].isSupported, "gauge not exist");

        uint256 _gaugeSize = gauges.length;
        uint256 _gaugeIndex = _gaugeSize;
        for (uint256 i = 0; i < _gaugeSize; i++) {
            if (gauges[i] == _gauge) {
                _gaugeIndex = i;
                break;
            }
        }
        // We must have found the gauge!
        assert(_gaugeIndex < _gaugeSize);

        gauges[_gaugeIndex] = gauges[_gaugeSize - 1];
        gauges.pop();
        delete gaugeData[_gauge];

        // Need to checkpoint with the token removed!
        checkpoint();

        emit GaugeRemoved(_gauge);
    }

    /**
     * @dev Updates the weight of the liquidity gauge.
     * @param _gauge Address of the liquidity gauge to update.
     * @param _weight New weight of the liquidity gauge.
     * @param _rewardPerDay AC reward for the gauge per day
     */
    function updateGauge(address _gauge, uint256 _weight, uint256 _rewardPerDay) external onlyGovernance {
        require(gaugeData[_gauge].isSupported, "gauge not exist");

        uint256 _oldWeight = gaugeData[_gauge].weight;
        uint256 _oldRate = gaugeData[_gauge].rate;

        uint256 _rate = _rewardPerDay.mul(WAD).div(DAY);
        gaugeData[_gauge].weight = _weight;
        gaugeData[_gauge].rate = _rate;

        // Need to checkpoint with the token removed!
        checkpoint();

        emit GaugeUpdated(_gauge, _oldWeight, _weight, _oldRate, _rate);
    }

    /**
     * @dev Used to salvage any ETH deposited to gauge controller by mistake. Only governance can salvage ETH.
     * The salvaged ETH is transferred to treasury for futher operation.
     */
    function salvage() external onlyGovernance {
        uint256 _amount = address(this).balance;
        address payable _target = payable(treasury);
        (bool success, ) = _target.call{value: _amount}(new bytes(0));
        require(success, 'ETH salvage failed');
    }

    /**
     * @dev Used to salvage any token deposited to gauge controller by mistake. Only governance can salvage token.
     * The salvaged token is transferred to treasury for futhuer operation.
     * Note: The gauge controller is not expected to hold any token, so any token is salvageable!
     * @param _token Address of the token to salvage.
     */
    function salvageToken(address _token) external onlyGovernance {
        IERC20Upgradeable _target = IERC20Upgradeable(_token);
        _target.safeTransfer(treasury, _target.balanceOf(address(this)));
    }
}