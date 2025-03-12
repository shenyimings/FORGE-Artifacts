// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct Stake {
    uint256 amount;
    uint256 startAt;
    uint256 endAt;
    string month;
}

contract Staking is Ownable {
    using SafeERC20 for ERC20;

    address public immutable self;
    address public immutable RITE;
    uint256 private constant MAX_CAP = 5000000000000000000000000; // 5M RITE
    uint256 public totalStaked;
    address public operator;
    uint256 private constant duration = 365 days; // staking duration is 12 months
    uint256 private constant APY = 50; // 50% APY
    //If the current owner wants to renounceOwnership, it will always be to this address
    address private constant FIXED_OWNER_ADDRESS =
        0x1156B992b1117a1824272e31797A2b88f8a7c729;

    constructor(address _rite) {
        require(_rite != address(0), "Staking: RITE address is zero");
        self = address(this);
        operator = msg.sender;
        RITE = _rite;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "Staking: caller is not the operator");
        _;
    }

    mapping(address => Stake[]) public stakes;
    mapping(address => mapping(string => bool)) public isStaked;

    // Event for staking
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        string month
    );
    // Event for unstaking
    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        string month
    );
    // Event for withdrawing
    event Withdrawn(address indexed to, uint256 amount);

    //Event for setting operator
    event OperatorSet(address indexed operator);

    /// @dev Allow owner to set operator address
    /// @param _operator The operator address
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "Staking: operator address is zero");
        operator = _operator;
        emit OperatorSet(_operator);
    }

    /// @dev Allow operator to set stake on behalf of user's subscription plan
    /// @param _amount The amount of RITE to stake, the amount user paid for subscription plan
    /// @param _address The user address
    /// @param _month The month of the subscription plan
    function stake(
        uint256 _amount,
        address _address,
        string memory _month
    ) external onlyOperator {
        require(_amount > 0, "Staking: amount is zero");
        require(_address != address(0), "Staking: address is zero");
        require(totalStaked < MAX_CAP, "Staking: max cap reached");

        require(
            isStaked[_address][_month] == false,
            "Staking: already staked for this month"
        );
        uint256 stakeAmount = totalStaked + _amount <= MAX_CAP
            ? _amount
            : MAX_CAP - totalStaked;

        totalStaked += stakeAmount;
        stakes[_address].push(
            Stake(
                stakeAmount,
                block.timestamp,
                block.timestamp + duration,
                _month
            )
        );

        isStaked[_address][_month] = true;
        emit Staked(_address, stakeAmount, block.timestamp, _month);
    }

    /// @dev Allow user to unstake their RITE after staking duration
    /// @param _index The index of the stake
    function unstake(uint _index) external {
        require(stakes[msg.sender].length > 0, "Staking: no stake");
        require(_index < stakes[msg.sender].length, "Staking: invalid stake");
        require(
            block.timestamp >= stakes[msg.sender][_index].endAt,
            "Staking: staking is not ended yet"
        );

        uint256 amount = stakes[msg.sender][_index].amount;
        uint256 reward = (amount * APY) / 100;
        require(
            ERC20(RITE).balanceOf(self) >= amount + reward,
            "Staking: insufficient balance"
        );

        emit Unstaked(
            msg.sender,
            amount,
            block.timestamp,
            stakes[msg.sender][_index].month
        );
        stakes[msg.sender][_index] = stakes[msg.sender][
            stakes[msg.sender].length - 1
        ];
        stakes[msg.sender].pop();

        ERC20(RITE).safeTransfer(msg.sender, amount + reward);
    }

    /// @dev Allow user to see their stakes
    /// @param _address The user address
    /// @return The stakes of the user
    function getStakes(
        address _address
    ) external view returns (Stake[] memory) {
        return stakes[_address];
    }

    /// @dev Withdraw all tokens from the subscription contract
    function withdraw() external onlyOwner {
        //Balance of the subscription contract
        uint256 amount = ERC20(RITE).balanceOf(self);
        ERC20(RITE).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @dev Override renounceOwnership to transfer ownership to a fixed address, make sure contract owner will never be address(0)
    function renounceOwnership() public override onlyOwner {
        _transferOwnership(FIXED_OWNER_ADDRESS);
    }
}
