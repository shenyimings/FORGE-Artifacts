// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interface/IEventAggregator.sol";

contract EventAggregator is IEventAggregator, Initializable, OwnableUpgradeable {

    mapping(address => bool) public poolMap;

    function initialize() public initializer {
        __Ownable_init();
    }

    // Events.
    event Buy(
        address indexed pool_,
        address indexed who_,
        uint256 indexed policyIndex_,
        uint256 amount_,
        uint256 fromWeek_,
        uint256 toWeek_,
        string notes_
    );

    event Deposit(
        address indexed pool_,
        address indexed who_,
        uint256 amount_
    );

    event Withdraw(
        address indexed pool_,
        address indexed who_,
        uint256 indexed requestIndex_,
        uint256 share_
    );

    event WithdrawPending(
        address indexed pool_,
        address indexed who_,
        uint256 indexed requestIndex_
    );

    event WithdrawReady(
        address indexed pool_,
        address indexed who_,
        uint256 indexed requestIndex_,
        bool succeeded_
    );

    // At most 3 indexed arguments is allowed by solidity
    event Refund(
        address pool_,
        uint256 indexed policyIndex_,
        uint256 indexed week_,
        address indexed who_,
        uint256 amount_
    );

    event Claim(
        uint256 policyIndex_,
        uint256 amount_,
        address receipient_
    );

    event ChangePoolManager(
        address poolManager_
    );

    event AddToCommittee(
        address who_
    );

    event RemoveFromCommittee(
        address who_
    );

    event ChangeCommitteeThreshold(
        uint256 threshold_
    );

    event Vote(
        uint256 requestIndex_,
        bool support_
    );

    event Execute(
        uint256 requestIndex_
    );

    function setPool(address pool_, bool on_) external onlyOwner {
        poolMap[pool_] = on_;
    }

    modifier onlyPool() {
        require(poolMap[msg.sender], "Only pool");
        _;
    } 

    function buy(
        address who_,
        uint256 policyIndex_,
        uint256 amount_,
        uint256 fromWeek_,
        uint256 toWeek_,
        string calldata notes_
    ) external onlyPool {
        emit Buy(
            msg.sender,
            who_,
            policyIndex_,
            amount_,
            fromWeek_,
            toWeek_,
            notes_
        );
    }

    function deposit(
        address who_,
        uint256 amount_
    ) external onlyPool {
        emit Deposit(
            msg.sender,
            who_,
            amount_
        );
    }

    function withdraw(
        address who_,
        uint256 requestIndex_,
        uint256 share_
    ) external onlyPool {
        emit Withdraw(
            msg.sender,
            who_,
            requestIndex_,
            share_
        );
    }

    function withdrawPending(
        address who_,
        uint256 requestIndex_
    ) external onlyPool {
        emit WithdrawPending(
            msg.sender,
            who_,
            requestIndex_
        );
    }

    function withdrawReady(
        address who_,
        uint256 requestIndex_,
        bool succeeded_
    ) external onlyPool {
        emit WithdrawReady(
            msg.sender,
            who_,
            requestIndex_,
            succeeded_
        );
    }

    function refund(
        uint256 policyIndex_,
        uint256 week_,
        address who_,
        uint256 amount_
    ) external onlyPool {
        emit Refund(
            msg.sender,
            policyIndex_,
            week_,
            who_,
            amount_
        );
    }

    function claim(
        uint256 policyIndex_,
        uint256 amount_,
        address receipient_
    ) external onlyPool {
        emit Claim(
            policyIndex_,
            amount_,
            receipient_
        );
    }

    function changePoolManager(
        address poolManager_
    ) external onlyPool {
        emit ChangePoolManager(
            poolManager_
        );
    }

    function addToCommittee(address who_) external onlyPool {
        emit AddToCommittee(
            who_
        );
    }

    function removeFromCommittee(address who_) external onlyPool {
        emit RemoveFromCommittee(
            who_
        );
    }

    function changeCommitteeThreshold(uint256 threshold_) external onlyPool {
        emit ChangeCommitteeThreshold(
            threshold_
        );
    }

    function vote(
        uint256 requestIndex_,
        bool support_
    ) external onlyPool {
        emit Vote(
            requestIndex_,
            support_
        );
    }

    function execute(uint256 requestIndex_) external onlyPool {
        emit Execute(
            requestIndex_
        );
    }
}
