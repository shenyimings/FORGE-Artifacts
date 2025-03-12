// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MasterChefInfoStruct {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardETHDebt; // Reward debt in ETH.
    }
}

interface IMasterChef {
    function userInfo(
        address _user
    ) external view returns (MasterChefInfoStruct.UserInfo memory);

    function deposit(address _user, uint256 _amount) external payable;
}

contract LiquidityETHPoolV2 is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // Info of each user.
    struct WithdrawInfo {
        uint256 amount; // How many LP tokens the user has withdraw.
        bool isQueued; // queue done or not
        bool isMigrate; // migrate done or not
        bool withdrawStatus; // withdraw done or not
        bool isDisableByAdmin; // disable by admin or not
        uint256 currentQueuedETH; // current total Queued ETH
        uint256 position; // queue position
    }

    mapping(address => WithdrawInfo) public withdrawInfo;

    address public masterChefETHV1;
    address public masterChefETHV2;

    uint256 public totalQueuedETH;
    uint256 public totalPooledETH;
    uint256 public totalWithdrawETH;
    uint256 public queueCount;

    event AddETHInPool(uint256 amount);
    event WithdrawETHToken(address indexed user, uint256 amount);
    event EmergencyWithdrawTokensWEvent(address _to, uint256 _amount);
    event QueueRequestEvent(
        address _user,
        uint256 _amount,
        uint256 _totalQueuedETH,
        uint256 _queueCount,
        bool _isMigrate
    );
    event UnstakeEvent(address _user, uint256 _amount);
    event DisableUserEvent(address _user, bool _status, bool _isQueued);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    //to recieve ETH from admin
    receive() external payable {}

    function initialize(
        address initialOwner,
        address _masterChefETHV1,
        address _masterChefETHV2
    ) public initializer {
        require(initialOwner != address(0), "Invalid Owner Address");
        require(
            _masterChefETHV1 != address(0),
            "Invalid MasterChef ETH V1 Address"
        );
        require(
            _masterChefETHV2 != address(0),
            "Invalid MasterChef ETH V2 Address"
        );
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        masterChefETHV1 = _masterChefETHV1;
        masterChefETHV2 = _masterChefETHV2;
    }

    /**
     * @dev Queues a withdrawal request.
     * @param _isMigrate Whether the withdrawal is a migration.
     */
    function queueRequest(bool _isMigrate) public nonReentrant {
        MasterChefInfoStruct.UserInfo memory userInfo = IMasterChef(
            masterChefETHV1
        ).userInfo(msg.sender);
        WithdrawInfo storage user = withdrawInfo[msg.sender];

        require(userInfo.amount > 0, "Not Staked In V1 Pool");
        require(user.isDisableByAdmin != true, "Not allowed");
        require(
            !user.isQueued && !user.withdrawStatus,
            "Already Queued/Unstake"
        );
        require((userInfo.amount - user.amount) > 0, "Can not queue");

        totalQueuedETH = totalQueuedETH + userInfo.amount;
        user.amount = user.amount + userInfo.amount;
        user.isQueued = true;
        user.isMigrate = _isMigrate;
        user.currentQueuedETH = totalQueuedETH;
        user.position = queueCount;
        queueCount = queueCount + 1;

        emit QueueRequestEvent(
            msg.sender,
            userInfo.amount,
            totalQueuedETH,
            queueCount,
            _isMigrate
        );
    }

    /**
     * @dev Processes a withdrawal request.
     */
    function unstake() public nonReentrant {
        WithdrawInfo storage user = withdrawInfo[msg.sender];

        require(user.amount > 0, "Not Staked");
        require(user.isDisableByAdmin != true, "Not allowed");
        require(
            user.isQueued && !user.withdrawStatus,
            "Already Unstake or Not Queued"
        );
        require(
            user.currentQueuedETH <= totalPooledETH,
            "Not Enough Pool Amount"
        );

        user.withdrawStatus = true;
        totalWithdrawETH = totalWithdrawETH + user.amount;
        if (user.isMigrate) {
            IMasterChef(masterChefETHV2).deposit{value: user.amount}(
                msg.sender,
                user.amount
            );
        } else {
            payable(msg.sender).transfer(user.amount);
        }

        emit UnstakeEvent(msg.sender, user.amount);
    }

    // Safe add LP in pool
    function addETHInPool(
        uint256 _amount
    ) public payable onlyOwner nonReentrant {
        require(msg.value == _amount, "Eth must be equal to staked amount");
        require(_amount > 0, "ETH amount must be greater than 0");
        totalPooledETH = totalPooledETH + _amount;

        emit AddETHInPool(_amount);
    }

    function disableUser(
        address _user,
        bool _status
    ) public payable onlyOwner nonReentrant {
        WithdrawInfo storage user = withdrawInfo[_user];
        require(user.isDisableByAdmin != _status, "Already in same status");
        if (user.withdrawStatus) {
            require(
                (_status == false) && user.isDisableByAdmin == true,
                "Can not activate user"
            );
        }

        if (user.isQueued && !user.isDisableByAdmin) {
            user.withdrawStatus = true;
            if(user.currentQueuedETH <= totalPooledETH) {
                payable(owner()).transfer(user.amount);
            }
        } else if (user.isQueued && user.isDisableByAdmin) {
            user.withdrawStatus = false;
        }
        user.isDisableByAdmin = _status;

        emit DisableUserEvent(_user, _status, user.isQueued);
    }

    /**
     * @dev Used only by admin or owner, used to withdraw locked tokens in emergency
     *Working on v-empire and revolt task

     * @param _to address of tokens receiver
     * @param _amount amount of token and must be less than total locked amount
     */
    function emergencyWithdrawTokens(
        address payable _to,
        uint256 _amount
    ) public onlyOwner nonReentrant {
        require(_to != address(0), "Invalid _to address");
        uint256 tokenBal = address(this).balance;
        require(tokenBal >= _amount, "Insufficient amount");
        _to.transfer(_amount);
        emit EmergencyWithdrawTokensWEvent(_to, _amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
