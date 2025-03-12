//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../libraries/TransferHelper.sol";
import "./Whitelist.sol";

contract WhitelistRaising is ReentrancyGuard, Ownable, Pausable, Whitelist {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many tokens the user has provided.
        bool claimed; // default false
    }
    // The offering token
    ERC20 public offeringToken;
    // The timestamp when raising starts
    uint256 public startTime;
    // The timestamp when raising ends
    uint256 public endTime;
    // The timestamp user staring harvest
    uint256 public harvestTime;
    // total amount of raising tokens need to be raised
    uint256 public raisingAmount;
    // total amount of offeringToken that will offer
    uint256 public offeringAmount;
    // total amount of raising tokens that have already raised
    uint256 public totalAmount;
    // address => amount
    mapping(address => UserInfo) public userInfo;
    // participators
    address[] public addressList;

    // maximum wallet address
    uint256 public maximumAddress;

    // Event
    event Deposit(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 offeringAmount);

    constructor(
        ERC20 _offeringToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _harvestTime,
        uint256 _offeringAmount,
        uint256 _raisingAmount,
        uint256 _maxAddr
    ) public {
        require(
            _harvestTime >= _endTime &&
            _endTime > _startTime &&
            _startTime > block.timestamp
        );
        offeringToken = _offeringToken;
        startTime = _startTime;
        endTime = _endTime;
        harvestTime = _harvestTime;
        offeringAmount = _offeringAmount;
        raisingAmount = _raisingAmount;
        maximumAddress= _maxAddr;
        totalAmount = 0;
    }

    modifier depositAllowed(uint256 _amount) {
        require(
            block.timestamp > startTime && block.timestamp < endTime,
            "not raising time"
        );
        require(_amount > 0, "need _amount > 0");
        require(addressList.length < maximumAddress, "full");
        _;
    }

    modifier harvestAllowed() {
        require(block.timestamp > harvestTime, "not harvest time");
        require(userInfo[msg.sender].amount > 0, "have you participated?");
        require(!userInfo[msg.sender].claimed, "nothing to harvest");
        _;
    }

    function updateStartTime(uint256 _newTime) public onlyOwner {
        require(_newTime > block.timestamp && _newTime < endTime, "time invalid!!");
        startTime = _newTime;
    }

    function updateHarvestTime(uint256 _newTime) public onlyOwner {
        require(
            _newTime > block.timestamp && _newTime > endTime,
            "time invalid!!"
        );
        harvestTime = _newTime;
    }

    function updateEndTime(uint256 _newTime) public onlyOwner {
        require(
            _newTime > block.timestamp && _newTime < harvestTime,
            "time invalid!!"
        );
        endTime = _newTime;
    }

    function setOfferingAmount(uint256 _offerAmount) public onlyOwner {
        require(block.timestamp < startTime, "no");
        offeringAmount = _offerAmount;
    }

    function setRaisingAmount(uint256 _raisingAmount) public onlyOwner {
        require(block.timestamp < startTime, "no");
        raisingAmount = _raisingAmount;
    }

    function maxAllocation () view public returns (uint256) {
        return raisingAmount.div(maximumAddress);
    } 

    function deposit(uint256 _amount)
        public
        payable
        nonReentrant
        depositAllowed(_amount)
        whenNotPaused
    {
        require(
            maxAllocation() > userInfo[msg.sender].amount,
            "not eligible amount!!"
        );
        uint256 eligibleAmount = maxAllocation() - userInfo[msg.sender].amount;
        uint256 amount = _amount;
        if (eligibleAmount < _amount) {
            amount = eligibleAmount;
        }
        require(msg.value >= amount, "amount not enough");
        if (msg.value > amount) {
            TransferHelper.safeTransferKAI(msg.sender, msg.value - amount);
        }        
        if (userInfo[msg.sender].amount == 0) {
            addressList.push(address(msg.sender));
        }
        userInfo[msg.sender].amount = userInfo[msg.sender].amount.add(amount);
        totalAmount = totalAmount.add(amount);
        emit Deposit(msg.sender, amount);
    }

    function harvest() public nonReentrant harvestAllowed whenNotPaused {
        uint256 offeringTokenAmount = getOfferingAmount(msg.sender);
        offeringToken.safeTransfer(address(msg.sender), offeringTokenAmount);
        userInfo[msg.sender].claimed = true;
        emit Harvest(msg.sender, offeringTokenAmount);
    }

    // get the amount of Offering token you will get
    function getOfferingAmount(address _user) public view returns (uint256) {
        return userInfo[_user].amount.mul(offeringAmount).div(raisingAmount);
    }

    function getAddressListLength() external view returns (uint256) {
        return addressList.length;
    }

    function finalWithdraw(address _destination) public onlyOwner {
        TransferHelper.safeTransferKAI(_destination, address(this).balance);
    }

    function emergencyWithdraw(address token, address payable to)
        public
        onlyOwner
    {
        if (token == address(0)) {
            to.transfer(address(this).balance);
        } else {
            ERC20(token).safeTransfer(
                to,
                ERC20(token).balanceOf(address(this))
            );
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
