pragma solidity ^0.4.17;

import './TokenController.sol';
import './SafeMath.sol';
import './Ownable.sol';

/**
 * @title Hodler
 * @dev Handles hodler reward, TokenController should create and own it.
 */
contract Hodler is Ownable {
    using SafeMath for uint;

    // HODLER reward tracker
    // stake amount per address
    struct HODL {
        uint256 stake;
        // moving ANY funds invalidates hodling of the address
        bool invalid;
        bool claimed3M;
        bool claimed6M;
        bool claimed9M;
    }

    mapping (address => HODL) public hodlerStakes;

    // total current staking value and hodler addresses
    uint256 public hodlerTotalValue;
    uint256 public hodlerTotalCount;

    // store dates and total stake values for 3 - 6 - 9 months after normal sale
    uint256 public hodlerTotalValue3M;
    uint256 public hodlerTotalValue6M;
    uint256 public hodlerTotalValue9M;
    uint256 public hodlerTimeStart;
    uint256 public hodlerTime3M;
    uint256 public hodlerTime6M;
    uint256 public hodlerTime9M;

    // reward HEAL token amount
    uint256 public TOKEN_HODL_3M;
    uint256 public TOKEN_HODL_6M;
    uint256 public TOKEN_HODL_9M;

    // total amount of tokens claimed so far
    uint256 public claimedTokens;

    
    event LogHodlSetStake(address indexed _setter, address indexed _beneficiary, uint256 _value);
    event LogHodlClaimed(address indexed _setter, address indexed _beneficiary, uint256 _value);
    event LogHodlStartSet(address indexed _setter, uint256 _time);


    /// @dev Only before hodl is started
    modifier beforeHodlStart() {
        if (hodlerTimeStart == 0 || now <= hodlerTimeStart)
            _;
    }

    /// @dev Contructor, it should be created by a TokenController
    function Hodler(uint256 _stake3m, uint256 _stake6m, uint256 _stake9m) {
        TOKEN_HODL_3M = _stake3m;
        TOKEN_HODL_6M = _stake6m;
        TOKEN_HODL_9M = _stake9m;
    }

    /// @notice Adding hodler stake to an account
    /// @dev Only owner contract can call it and before hodling period starts
    /// @param _beneficiary Recepient address of hodler stake
    /// @param _stake Amount of additional hodler stake
    function addHodlerStake(address _beneficiary, uint256 _stake) public onlyOwner beforeHodlStart {
        // real change and valid _beneficiary is needed
        if (_stake == 0 || _beneficiary == address(0))
            return;
        
        // add stake and maintain count
        if (hodlerStakes[_beneficiary].stake == 0)
            hodlerTotalCount = hodlerTotalCount.add(1);

        hodlerStakes[_beneficiary].stake = hodlerStakes[_beneficiary].stake.add(_stake);

        hodlerTotalValue = hodlerTotalValue.add(_stake);

        LogHodlSetStake(msg.sender, _beneficiary, hodlerStakes[_beneficiary].stake);
    }

    /// @notice Setting hodler stake of an account
    /// @dev Only owner contract can call it and before hodling period starts
    /// @param _beneficiary Recepient address of hodler stake
    /// @param _stake Amount to set the hodler stake
    function setHodlerStake(address _beneficiary, uint256 _stake) public onlyOwner beforeHodlStart {
        // real change and valid _beneficiary is needed
        if (hodlerStakes[_beneficiary].stake == _stake || _beneficiary == address(0))
            return;
        
        // add stake and maintain count
        if (hodlerStakes[_beneficiary].stake == 0 && _stake > 0) {
            hodlerTotalCount = hodlerTotalCount.add(1);
        } else if (hodlerStakes[_beneficiary].stake > 0 && _stake == 0) {
            hodlerTotalCount = hodlerTotalCount.sub(1);
        }

        uint256 _diff = _stake > hodlerStakes[_beneficiary].stake ? _stake.sub(hodlerStakes[_beneficiary].stake) : hodlerStakes[_beneficiary].stake.sub(_stake);
        if (_stake > hodlerStakes[_beneficiary].stake) {
            hodlerTotalValue = hodlerTotalValue.add(_diff);
        } else {
            hodlerTotalValue = hodlerTotalValue.sub(_diff);
        }
        hodlerStakes[_beneficiary].stake = _stake;

        LogHodlSetStake(msg.sender, _beneficiary, _stake);
    }

    /// @notice Setting hodler start period.
    /// @param _time The time when hodler reward starts counting
    function setHodlerTime(uint256 _time) public onlyOwner beforeHodlStart {
        require(_time >= now);

        hodlerTimeStart = _time;
        hodlerTime3M = _time.add(90 days);
        hodlerTime6M = _time.add(180 days);
        hodlerTime9M = _time.add(270 days);

        LogHodlStartSet(msg.sender, _time);
    }

    /// @notice Invalidates hodler account 
    /// @dev Gets called by EthealController#onTransfer before every transaction
    function invalidate(address _account) public onlyOwner {
        if (hodlerStakes[_account].stake > 0 && !hodlerStakes[_account].invalid) {
            hodlerStakes[_account].invalid = true;
            hodlerTotalValue = hodlerTotalValue.sub(hodlerStakes[_account].stake);
            hodlerTotalCount = hodlerTotalCount.sub(1);
        }

        // update hodl total values "automatically" - whenever someone sends funds thus
        updateAndGetHodlTotalValue();
    }

    /// @notice Claiming HODL reward for msg.sender
    function claimHodlReward() public {
        claimHodlRewardFor(msg.sender);
    }

    /// @notice Claiming HODL reward for an address
    function claimHodlRewardFor(address _beneficiary) public {
        // only when the address has a valid stake
        require(hodlerStakes[_beneficiary].stake > 0 && !hodlerStakes[_beneficiary].invalid);

        uint256 _stake = 0;
        
        // update hodl total values
        updateAndGetHodlTotalValue();

        // claim hodl if not claimed
        if (!hodlerStakes[_beneficiary].claimed3M && now >= hodlerTime3M) {
            _stake = _stake.add(hodlerStakes[_beneficiary].stake.mul(TOKEN_HODL_3M).div(hodlerTotalValue3M));
            hodlerStakes[_beneficiary].claimed3M = true;
        }
        if (!hodlerStakes[_beneficiary].claimed6M && now >= hodlerTime6M) {
            _stake = _stake.add(hodlerStakes[_beneficiary].stake.mul(TOKEN_HODL_6M).div(hodlerTotalValue6M));
            hodlerStakes[_beneficiary].claimed6M = true;
        }
        if (!hodlerStakes[_beneficiary].claimed9M && now >= hodlerTime9M) {
            _stake = _stake.add(hodlerStakes[_beneficiary].stake.mul(TOKEN_HODL_9M).div(hodlerTotalValue9M));
            hodlerStakes[_beneficiary].claimed9M = true;
        }

        if (_stake > 0) {
            // increasing claimed tokens
            claimedTokens = claimedTokens.add(_stake);

            // transferring tokens
            require(TokenController(owner).ethealToken().transfer(_beneficiary, _stake));

            // log
            LogHodlClaimed(msg.sender, _beneficiary, _stake);
        }
    }

    /// @notice claimHodlRewardFor() for multiple addresses
    /// @dev Anyone can call this function and distribute hodl rewards
    /// @param _beneficiaries Array of addresses for which we want to claim hodl rewards
    function claimHodlRewardsFor(address[] _beneficiaries) external {
        for (uint256 i = 0; i < _beneficiaries.length; i++)
            claimHodlRewardFor(_beneficiaries[i]);
    }

    /// @notice Setting 3 - 6 - 9 months total staking hodl value if time is come
    function updateAndGetHodlTotalValue() public returns (uint) {
        if (now >= hodlerTime3M && hodlerTotalValue3M == 0) {
            hodlerTotalValue3M = hodlerTotalValue;
        }

        if (now >= hodlerTime6M && hodlerTotalValue6M == 0) {
            hodlerTotalValue6M = hodlerTotalValue;
        }

        if (now >= hodlerTime9M && hodlerTotalValue9M == 0) {
            hodlerTotalValue9M = hodlerTotalValue;

            // since we can transfer more tokens to this contract, make it possible to retain more than the predefined limit
            TOKEN_HODL_9M = TokenController(owner).ethealToken().balanceOf(this).sub(TOKEN_HODL_3M).sub(TOKEN_HODL_6M).add(claimedTokens);
        }

        return hodlerTotalValue;
    }
}