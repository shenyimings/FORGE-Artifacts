// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IVotingEscrow.sol";

contract AirdropTeam is ReentrancyGuard {

    using SafeERC20 for IERC20;


    uint256 constant public PRECISION = 1000;
    uint256 immutable START_CLAIM;
    uint256 immutable START_VESTING;
    uint256 public totalAllocation;
    uint256 veSHARE = 500; // 50% veCHR / CHR
    bool seeded;
    bool configured;

    uint256 totalToReceive;

    address public owner;
    address public ve;
    
    IERC20 public token;
    bool public paused =false;

    
    uint public constant LOCK = 86400 * 7 * 52 * 2;
    uint public constant VESTING = 86400 * 7 * 52 * 2;
    

    mapping(address => uint) public claimableAmount;
    mapping(address => bool) public claimedVeCHR;
    mapping(address => uint) public amountReceived;


    modifier onlyOwner {
        require(msg.sender == owner, 'not owner');
        _;
    }

    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);
    event Claimed(address _who, uint amount, bool veCHR);
    event AllocationSet(address _who, uint amount);


    constructor(address _token, address _ve) {
        owner = msg.sender;
        token = IERC20(_token);
        ve = _ve;
        //START_CLAIM = 1619308800;   //GMT: April 27, 2023 12:00:00 AM + 1 week  (epoch 1)
        START_CLAIM = 1682553600;   //GMT: April 27, 2023 12:00:00 AM + 1 week  (epoch 1)
        START_VESTING = START_CLAIM + 1 weeks;
    }


    function deposit(uint256 amount) external {
        
        require(msg.sender == owner || msg.sender == address(0x25eC5c30bf75BF0BD7D80dfa31709B6038b16761));
        require(!seeded, "Already deposited initial amount");

        token.safeTransferFrom(msg.sender, address(this), amount);
        totalAllocation += amount;

        seeded = true;
        emit Deposit(amount);
    }
    
    /* 
        OWNER FUNCTIONS
    */

    function setOwner(address _owner) external onlyOwner{
        owner = _owner;
    }

    /// @notice set user infromation for the airdrop claim
    /// @param _who who can receive the airdrop
    /// @param _amount the amount he can receive
    function setTeamMembers(address[] memory _who, uint256[] memory _amount) external onlyOwner {
        require(_who.length == _amount.length);
        require(!configured, "Team members already configured");

        uint _totalToAllocated;
        for (uint i = 0; i < _who.length; i++) {
            claimableAmount[_who[i]] += _amount[i];
            require(_totalToAllocated + _amount[i] <= totalAllocation, "Not enough allocation");
            _totalToAllocated += _amount[i];
            emit AllocationSet(_who[i], _amount[i]);
        }
        totalToReceive += _totalToAllocated;

        configured = true;
        
    }



    function claim() public nonReentrant {
        require(claimableAmount[msg.sender] != 0,"No Team allocation");
        require(!paused);
        // check user has airdrop available
        if (block.timestamp > START_CLAIM) {
            uint amount = claimableAmount[msg.sender]*veSHARE/PRECISION;
            if (!claimedVeCHR[msg.sender]) {
                claimedVeCHR[msg.sender] = true;

                token.approve(ve, 0);
                token.approve(ve, amount);
                IVotingEscrow(ve).create_lock_for(amount, LOCK, msg.sender);
                
                emit Claimed (msg.sender, amount, true);
            }

            amount = claimableAmount[msg.sender]-amount;

            if (block.timestamp > START_VESTING) {
                
                uint timeElapsed = block.timestamp - START_VESTING;

                if ( timeElapsed > VESTING) timeElapsed = VESTING;
                
                uint percentToReceive = timeElapsed * PRECISION / VESTING;
                
                uint amountToReceive = (amount * percentToReceive / PRECISION) - amountReceived[msg.sender];
                
                amountReceived[msg.sender] += amountToReceive;

                token.transfer(msg.sender, amountToReceive);

                emit Claimed (msg.sender, amountToReceive, false);

            }
            
        }
    }

    function emergencyWithdraw(address _token, uint amount) onlyOwner external{
        address ms = 0x25eC5c30bf75BF0BD7D80dfa31709B6038b16761;
        IERC20(_token).safeTransfer(ms, amount);
        paused=true;

        emit Withdraw(amount);
    }

    fallback() external {
        claim();
    }

}