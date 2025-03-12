pragma solidity ^0.6.0;
// SPDX-License-Identifier: MIT
// Libs
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
// Used contracts
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title  lpTokenWrapper
 * @author Synthetix (forked from /Synthetixio/synthetix/contracts/StakingRewards.sol)
 *         Audit: https://github.com/sigp/public-audits/blob/master/synthetix/unipool/review.pdf
 *         Changes by: SPO.
 * @notice LP Token wrapper to facilitate tracking of staked balances
 * @dev    Changes:
 *          - Added UserData and _historyTotalSupply to track history balances
 *          - Changing 'stake' and 'withdraw' to internal funcs
 */
contract LPTokenWrapper is ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public lpToken;

    uint256 private _totalSupply;
    mapping (uint256 => uint256) private _historyTotalSupply;
    mapping(address => uint256) private _balances;
    //Hold in seconds before withdrawal after last time staked
    uint256 public holdTime;
    
    struct UserData {
        //Period first time deposited or last finished period rewards calculated
        uint256 period;
        //Last time deposited. used to implement holdDays
        uint256 lastTime;
        bool exists;
        mapping (uint256 => uint) historyBalance;
    }

    mapping (address => UserData) private userData;

    /**
     * @dev TokenWrapper constructor
     * @param _lpToken Wrapped token to be staked
     * @param _holdDays Hold days after last deposit
     */
    constructor(address _lpToken, uint256 _holdDays) internal {
        lpToken = IERC20(_lpToken);
        holdTime = _holdDays.mul(1 days);
    }

    /**
     * @dev Get the total amount of the staked token
     * @return uint256 total supply
     */
    function totalSupply()
        public
        view
        returns (uint256)
    {
        return _totalSupply;
    }

    /**
     * @dev Get the total amount of the staked token
     * @param _period Period for which total supply returned
     * @return uint256 total supply
     */
    function historyTotalSupply(uint256 _period)
        public
        view
        returns (uint256)
    {
        return _historyTotalSupply[_period];
    }

    /**
     * @dev Get the balance of a given account
     * @param _address User for which to retrieve balance
     */
    function balanceOf(address _address)
        public
        view
        returns (uint256)
    {
        return _balances[_address];
    }

    /**
     * @dev Deposits a given amount of lpToken from sender
     * @param _amount Units of lpToken
     */
    function _stake(uint256 _amount, uint256 _period)
        internal
        nonReentrant
    {

        _totalSupply = _totalSupply.add(_amount);
        _updateHistoryTotalSupply(_period);
        _balances[msg.sender] = _balances[msg.sender].add(_amount);
        UserData storage user = userData[msg.sender]; 
        if(!user.exists){
            user.period = _period;
            user.exists = true;
        }
        user.historyBalance[_period] = _balances[msg.sender];
        user.lastTime = block.timestamp;
        lpToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @dev Withdraws a given stake from sender
     * @param _amount Units of lpToken
     */
    function _withdraw(uint256 _amount, uint256 _period)
        internal
        nonReentrant
    {
        //Check first if user has sufficient balance, added due to hold requrement 
        //("Cannot withdraw, tokens on hold" will be fired even if user  has no balance)
        require(_balances[msg.sender] >= _amount, "Not enough balance");
        UserData storage user = userData[msg.sender]; 
        require(block.timestamp.sub(user.lastTime) >= holdTime, "Cannot withdraw, tokens on hold");
        _totalSupply = _totalSupply.sub(_amount);
        _updateHistoryTotalSupply(_period);
        _balances[msg.sender] = _balances[msg.sender].sub(_amount);
        user.historyBalance[_period] = _balances[msg.sender];
        lpToken.safeTransfer(msg.sender, _amount);
    }
    
    /**
     * @dev Updates history total supply
     * @param _period Current period
     */
     function _updateHistoryTotalSupply(uint256 _period)
        internal
    {
        _historyTotalSupply[_period] = _totalSupply;
    }
    
    /**
     * @dev Returns User Data
     * @param _address address of the User
     */
     function getUserData(address _address)
        internal
        view
        returns (UserData storage)
    {
        return userData[_address];
    }

    /**
     * @dev Sets user's period and balance for that period
     * @param _address address of the User
     */
     function _updateUser(address _address, uint256 _period)
        internal
    {
        userData[_address].period = _period;
        userData[_address].historyBalance[_period] = _balances[_address];
    }

    /**
     * @dev Returns true if uders exists
     * @param _address address of the User
     */
     function isUserExist(address _address)
        internal
        view
        returns (bool)
    {
        return userData[_address].exists;
    }    

}