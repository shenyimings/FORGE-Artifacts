// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

library SafeERC20 {
    using SafeMath for uint;

    function safeTransfer(IERC20 token, address to, uint value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(isContract(address(token)), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }

	function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}

contract WhatsFund {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	event regLevelEvent(
        address indexed _user,
        address indexed _referrer,
        address  originalRefer,
        uint256 _amount,
        uint256 _time
    );

    event reTopupLevelEvent(
        address indexed _user,
        uint256 _amount,
        uint256 _time
    );

    event roiDirectEvent(
        address indexed _user,
        uint256 _amount,
        uint256 _time
    );

    event levelIncomeEvent(
        address indexed _user,
        uint256 _amount,
        uint256 _time
    );

    uint256 REFERRER_1_LEVEL_LIMIT;
    struct UserStruct {
      bool isExist;
      uint256 id;
      uint256 referrerID;
      uint256 directIncome;
      address[] referral;
      address[] allDirect;
      uint256 generationIncome;
      uint256 earnedAmount;
      address parentAddress;
      uint256 teamCount;
      uint256 roiFrom;
      uint256 roiTo;
      uint256 retopupTimes;
      uint256 withdrawAmount;
      uint256 missedIncome;
    }

    mapping(address => UserStruct) public users;
    mapping(uint256 => address) public userList;
    uint256 public currUserID;
    uint256 public totalUsers;
    uint256 public totalPayouts;
    address public ownerWallet;
    uint256 public joinAmount;
    uint256 public referAmount;
    uint256 public adminAmount;
    uint256 public generationAmount;
    uint256 public persecondreward;
    address[] public joinedAddress;
    IERC20 public USDTAddress;
    mapping(address => uint256) public userJoinTimestamps;
    mapping(address => uint256[6]) public generationIncomePerLevel;
    address public migrateOwner;
    mapping(address => bool) public isRetopup;
    uint256 public startDate;

    constructor(address _owner) public {
        ownerWallet = _owner;
        REFERRER_1_LEVEL_LIMIT = 2;
        currUserID = 1;
        totalUsers = 1;
        joinAmount = 100 * 1e18;
        referAmount = 10 * 1e18;
        adminAmount = 10 * 1e18;
        generationAmount = 10 * 1e18;
        USDTAddress = IERC20(0x55d398326f99059fF775485246999027B3197955);
        startDate = 1703170800;

        UserStruct memory userStruct;
        userStruct = UserStruct({
            isExist: true,
            id: currUserID,
            referrerID: 0,
            directIncome : 0,
            referral: new address[](0),
            allDirect : new address[](0),
            generationIncome : 0,
            earnedAmount : 0,
            teamCount : 0,
            parentAddress : address(0),
            roiFrom : 0,
            roiTo : block.timestamp + 3666 days,
            retopupTimes : 0,
            withdrawAmount : 0,
            missedIncome: 0
        });

        users[ownerWallet] = userStruct;
        userList[currUserID] = ownerWallet;
        generationIncomePerLevel[ownerWallet] = [0,0,0,0,0,0];
        userJoinTimestamps[ownerWallet] = block.timestamp;
        persecondreward = 92592589090909;  // 8 percentage per day total 15 days we conver the 120 percentage per sec and multiplied by 1e18
    }

    function getAllowance(address userAddress) public view returns(uint256) {
		return USDTAddress.allowance(userAddress, address(this));
	}

    function regUser(address _referrer, uint256 _amount) public {
        require(!users[msg.sender].isExist, "User exist");
        require(users[_referrer].isExist, "Invalid referal");
        require(_amount == joinAmount,"Invalid amount");
        require(block.timestamp > startDate, "Contract does not launch yet");

        uint256 _referrerID = users[_referrer].id;
        if (users[userList[_referrerID]].referral.length >= REFERRER_1_LEVEL_LIMIT) {
            _referrerID = users[findFreeReferrer(userList[_referrerID])].id;
        }
        currUserID++;
        totalUsers++;
        UserStruct memory userStruct;

        userStruct = UserStruct({
            isExist: true,
            id: currUserID,
            referrerID: _referrerID,
            directIncome : 0,
            referral: new address[](0),
            allDirect : new address[](0),
            generationIncome : 0,
            earnedAmount : 0,
            teamCount : 0,
            parentAddress : _referrer,
            roiFrom : block.timestamp,
            roiTo : block.timestamp + 15 days,
            retopupTimes : 0,
            withdrawAmount : 0,
            missedIncome:0
        });

        users[msg.sender] = userStruct;
        userList[currUserID] = msg.sender;
        address _upliner = userList[_referrerID];
        USDTAddress.safeTransferFrom(msg.sender,address(this),_amount);
        users[_upliner].referral.push(msg.sender);
        generationIncomePerLevel[msg.sender] = [0,0,0,0,0,0];

        address parent = userList[_referrerID];
        updateTeamCount(parent);
        USDTAddress.safeTransfer(ownerWallet, adminAmount);
        users[_referrer].directIncome += referAmount;
        USDTAddress.safeTransfer(_referrer, referAmount);
        users[_referrer].withdrawAmount += referAmount;
        totalPayouts += adminAmount;
        totalPayouts += referAmount;
        payForReferral(parent);
        joinedAddress.push(msg.sender);
        users[_referrer].allDirect.push(msg.sender);
        userJoinTimestamps[msg.sender] = block.timestamp;
        isRetopup[msg.sender] = true;
        emit regLevelEvent(msg.sender, userList[_referrerID], _referrer, _amount, block.timestamp);
    }

    function retopup(uint256 _amount) public {
        require(users[msg.sender].isExist, "User Not Exist");
        require(block.timestamp >= users[msg.sender].roiTo,"You are not eligible to retopup");
        require(_amount == joinAmount,"Invalid amount");
        updateRoi();
        USDTAddress.safeTransferFrom(msg.sender,address(this),_amount);
        users[msg.sender].retopupTimes++;
        users[msg.sender].roiFrom = block.timestamp;
        users[msg.sender].roiTo = block.timestamp + 15 days;
        USDTAddress.safeTransfer(ownerWallet, adminAmount);
        totalPayouts += adminAmount;
        payForReferral(userList[users[msg.sender].referrerID]);

        //fetch existing contract remaining amount
        if(isRetopup[msg.sender]){
            if(users[msg.sender].allDirect.length < 3){
              users[msg.sender].missedIncome += users[msg.sender].generationIncome;
              users[msg.sender].generationIncome = 0;
            }
        }

        emit reTopupLevelEvent(
            msg.sender,
            _amount,
            block.timestamp
        );
    }

    function cliamRoiDirectReward() public {
        require(users[msg.sender].isExist, "User Not exist");
        updateRoi();
        require(users[msg.sender].earnedAmount > 0, "No Balance");
        USDTAddress.safeTransfer(msg.sender, users[msg.sender].earnedAmount);
        totalPayouts += users[msg.sender].earnedAmount;
        users[msg.sender].withdrawAmount += users[msg.sender].earnedAmount;
        uint256 withdrawAmount = users[msg.sender].earnedAmount;
        users[msg.sender].earnedAmount = 0 ;

        emit roiDirectEvent(
            msg.sender,
            withdrawAmount,
            block.timestamp
        );
    }

    function cliamLevelReward() public {
        require(users[msg.sender].allDirect.length >= REFERRER_1_LEVEL_LIMIT, "Must Have 2 Direct Referral");
        require(users[msg.sender].generationIncome > 0 ,"No Balance");
        USDTAddress.safeTransfer(msg.sender ,users[msg.sender].generationIncome);
        totalPayouts += users[msg.sender].generationIncome;
        users[msg.sender].withdrawAmount += users[msg.sender].generationIncome;
        uint256 withdrawAmount = users[msg.sender].generationIncome;
        users[msg.sender].generationIncome = 0;

         emit levelIncomeEvent(
            msg.sender,
            withdrawAmount,
            block.timestamp
        );
    }

     function updateRoi() internal {
        if(users[msg.sender].roiFrom != 0){
            if(users[msg.sender].roiTo > users[msg.sender].roiFrom) {
                uint256 totime  = users[msg.sender].roiTo;
                if(block.timestamp < users[msg.sender].roiTo) {
                    totime  = block.timestamp;
                }
                uint256 percenatge = persecondreward * (totime - users[msg.sender].roiFrom) ;
                uint256 amount = (joinAmount * percenatge) / 1e20;  // we multiply 1e18 for percentage the why divide 1e20 instead of 1e2
                users[msg.sender].roiFrom = totime;
                users[msg.sender].earnedAmount += amount;
            }
        }
    }

    function checkRoi(address _user) public view returns(uint256) {
        if(users[_user].roiTo - users[_user].roiFrom != 0 && users[_user].roiFrom != 0) {
            uint256 totime  =users[_user].roiTo;
            if(block.timestamp < users[_user].roiTo) {
                 totime  = block.timestamp;
            }
            uint256 percenatge = persecondreward * (totime - users[_user].roiFrom) ;
            uint256 amount = (joinAmount * percenatge) / 1e20;
           return amount;
        } else {
            return 0;
        }
    }

    function updateTeamCount(address _parent) internal {
       if(_parent != address(0)){
         users[_parent].teamCount++;
         address referer = userList[users[_parent].referrerID];
         updateTeamCount(referer);
       }
    }

    function payForReferral(address _parent) internal {
        address nextParent = _parent;
        uint256 genAmount = generationAmount;
          for (uint i = 0; i < 6; i++) {
            if(nextParent != address(0) && users[nextParent].roiTo >= block.timestamp){
                    users[nextParent].generationIncome += genAmount;
                    generationIncomePerLevel[nextParent][i] += genAmount;
            } else {
                users[nextParent].missedIncome += genAmount;
            }
            nextParent =  userList[users[nextParent].referrerID];
          }
    }

    function findFreeReferrer(address _user) public view returns (address) {
        if (users[_user].referral.length < REFERRER_1_LEVEL_LIMIT) {
            return _user;
        }
        address[] memory referrals = new address[](600);
        referrals[0] = users[_user].referral[0];
        referrals[1] = users[_user].referral[1];
        address freeReferrer;
        bool noFreeReferrer = true;
        for (uint256 i = 0; i < 600; i++) {
            if (users[referrals[i]].referral.length == REFERRER_1_LEVEL_LIMIT) {
                if (i < 120) {
                    referrals[(i + 1) * 2] = users[referrals[i]].referral[0];
                    referrals[(i + 1) * 2 + 1] = users[referrals[i]].referral[1];
                }
            } else {
                noFreeReferrer = false;
                freeReferrer = referrals[i];
                break;
            }
        }
        require(!noFreeReferrer, "No Free Referrer");
        return freeReferrer;
    }

    function viewUserReferral(
        address _user
    ) public view returns (address[] memory) {
        return users[_user].referral;
    }

    function viewallDirectUserReferral(
        address _user
    ) public view returns (address[] memory) {
        return users[_user].allDirect;
    }

    function viewallgenerationIncome(
        address _user
    ) public view returns (uint256,uint256,uint256,uint256,uint256,uint256) {
        return (generationIncomePerLevel[_user][0],generationIncomePerLevel[_user][1],generationIncomePerLevel[_user][2],generationIncomePerLevel[_user][3],generationIncomePerLevel[_user][4],generationIncomePerLevel[_user][5]);
    }

    function getUsersJoinedLast24Hours() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < totalUsers; i++) {
            address userAddress = userList[i];
            if (
                userJoinTimestamps[userAddress] != 0 &&
                block.timestamp - userJoinTimestamps[userAddress] <= 86400
            ) {
                count++;
            }
        }
        return count;
    }
}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
}