// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interface/IXARDM.sol";

/// @notice ARDM Token Staking Contract with withdraw penalty & pausibility & access control feature
/// @notice Penalty System is added to incentivize stakings to keep their assets longer == less sell pressure
/// @notice Penalty System adds a new revenue model to protocol
/// @notice Access Control system adds more clear authorization than Ownership Model
/// @dev xARDM token must be deployed before staking contract
/// @dev xARDM token must give minter role after staking contract deployment
contract XARDMStaking is AccessControl,ReentrancyGuard {

    /// @notice Pauser Role used to pause Withdraw/Deposit functionality
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @dev Adds SafeTransfer functionalities to OpenZeppelin IERC20 Interface
    using SafeERC20 for IERC20;

    /// @notice Everytime an user deposits ARDM token we store their deposit time to calculate if their penalty time has been passed or not
    /// @notice If not passed then they have to pay penalty
    mapping(address => uint256) private _userDeadline;

    /// @notice Penalty Fee variable used to calculate the fee that gets transfered to treasury address
    /// @dev Initially set in construction
    uint256 public penaltyFee;

    /// @notice User must wait penalty deadline after deposit to withdraw without any penalty fee
    /// @notice If penalty deadline has not been passed then when user withdraw the penalty fee gets taken from their withdraw
    /// @dev Initially set in construction
    uint256 public penaltyDeadline;


    /// @notice Constants used for calculation
    uint public constant HUNDRED = 100e18;
    uint public constant ONE = 1e18;

    /// @notice Treasury Address is the one who adds ARDM Reward to contract & also the address where the penalty fee goes to
    /// @dev Initially set in construction
    address public treasuryAddress;

    /// @notice Used to calculate xARDM Rate & view contract total locked ARDM
    /// @dev Updated in Deposit,Withdraw Function
    /// @dev this way,front-running attack can be mitigated because only Treasury Address can add rewards to staking contract
    uint256 public totalARDM;

    /// @notice Used to transfer ARDM Tokens
    /// @dev Initially set in construction
    IERC20 immutable ARDM;

    /// @notice Used to mint/burn xARDM Tokens
    /// @dev Initially set in construction
    IXARDM immutable xARDM;

    /// @notice controls withdraw function
    bool public withdrawPaused;

    /// @notice controls deposit function
    bool public depositPaused;

    /// @notice controls penalty 
    bool public penaltyFeePaused;

    event DepositPaused(bool state);
    event WithdrawPaused(bool state);
    event PenaltyPaused(bool state);

    event Deposit(address indexed user, uint256 amount, uint256 xAmount);
    event Withdraw(address indexed user, uint256 amount, uint256 xAmount);

    event PenaltyFeeSent(address treasuryAddress, uint256 amount);

    event PenaltyDeadlineUpdated(uint256 oldDeadline, uint256 newDeadline);
    event PenaltyFeeUpdated(uint256 oldFee, uint256 newFee);
    event TreasuryAddressUpdated(
        address oldTreasuryAddress,
        address newTreasuryAddress
    );

    event RewardDeposit(uint256 amount, uint256 newSupply);

    /// @notice deposit pausibility modifier 
    modifier whenDepositNotPaused() {
        require(!depositPaused, "DEPOSIT PAUSED");
        _;
    }

    /// @notice withdraw pausibility modifier 
    modifier whenWithdrawNotPaused() {
        require(!withdrawPaused, "WITHDRAW PAUSED");
        _;
    }

    /// @notice Contract Intitialization 
    /// @dev After Contract Deployed , Owner of the contract should be migrated to an GnosisSafe MultiSignature Wallet with 3 Wallet Consensus Protocol
    /// @dev Contract Deployer will be emergency pauser if anything goes wrong
    constructor(
        IERC20 _ARDM,
        IXARDM _xARDM,
        uint256 _penaltyFee,
        uint256 _penaltyDeadline,
        address _treasuryAddress
    ) {
        require(address(_ARDM) != address(0), "ARDM ADDRESS ZERO");
        require(address(_treasuryAddress) != address(0), "TREASURY ADDRESS ZERO");

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());

        ARDM = _ARDM;
        xARDM = _xARDM;

        penaltyFee = _penaltyFee;
        penaltyDeadline = _penaltyDeadline;
        treasuryAddress = _treasuryAddress;
    }

    /// @notice Deposit model follows the traditional SushiSwap Staking Contract but with a penalty system
    /// @dev Added settings for deposit pause , for better security if anything goes wrong with staking contract 
    /// @dev Added settings for withdraw pause , for better security if anything goes wrong with staking contract 
    function deposit(uint256 _amount) external nonReentrant whenDepositNotPaused {
        require(_amount > 0, "AMOUNT ZERO");
        uint256 totalxARDM = xARDM.totalSupply();

        if (totalxARDM == 0 || totalARDM == 0) {
            xARDM.mint(msg.sender, _amount);
            emit Deposit(msg.sender, _amount, _amount);
        } else {
            uint256 mintAmount = (_amount * totalxARDM) / totalARDM;
            xARDM.mint(msg.sender, mintAmount);
            emit Deposit(msg.sender, _amount, mintAmount);
        }

        ARDM.safeTransferFrom(msg.sender, address(this), _amount);
        totalARDM += _amount;

        if (!penaltyFeePaused && _userDeadline[msg.sender] < block.timestamp) {
            _userDeadline[msg.sender] = block.timestamp + penaltyDeadline;
        }
    }

    /// @notice Only Treasury address can send rewards to staking contract , this way there won't be any front-running attacks
    function reward(uint256 _amount) external nonReentrant {
      require(msg.sender == treasuryAddress,"NOT TREASURY ADDRESS");

      ARDM.safeTransferFrom(msg.sender, address(this), _amount);
      totalARDM += _amount;
      emit RewardDeposit(_amount, totalARDM);
    }

    /// @notice Withdraw model follows the traditional SushiSwap Staking Contract but with a penalty system
    /// @dev Added settings for withdraw pause , for better security if anything goes wrong with staking contract 
    function withdraw(uint256 _amount) external nonReentrant whenWithdrawNotPaused {
        require(_amount > 0, "AMOUNT ZERO");
        uint256 totalxARDM = xARDM.totalSupply();

        uint256 transferAmount = (_amount * totalARDM) / totalxARDM;

        if (!penaltyFeePaused && _userDeadline[msg.sender] > block.timestamp) {
            uint256 fee = (transferAmount * penaltyFee) / HUNDRED;
            uint256 transferAmountMinusFee = transferAmount - fee;

            xARDM.burnFrom(msg.sender, _amount);
            ARDM.safeTransfer(msg.sender, transferAmountMinusFee);
            ARDM.safeTransfer(treasuryAddress, fee);
            emit PenaltyFeeSent(treasuryAddress, fee);
        } else {
            xARDM.burnFrom(msg.sender, _amount);
            ARDM.safeTransfer(msg.sender, transferAmount);
        }

        totalARDM -= transferAmount;
        emit Withdraw(msg.sender, transferAmount, _amount);
    }

    /// @notice Utility Function to check if staker deadline has been passed
    /// @dev Helpful to check customer problems involving penalty deadline 
    function hasUserDeadlinePassed(address account)
        external
        view
        returns (bool)
    {
        require(account != address(0), "ADDRESS ZERO");
        if (_userDeadline[account] > block.timestamp) {
            return false;
        } else {
            return true;
        }
    }

    /// @notice Utility Function to get current 1 xARDM rate
    function getXARDMRate() external view returns (uint256) {
        uint256 totalxARDM = xARDM.totalSupply();

        if (totalARDM == 0 || totalxARDM == 0) {
            return 0;
        }

        return (ONE * totalARDM) / totalxARDM;
    }

    /// @notice Utility Function to get current X amount xARDM rate
    function getXARDMAmountRate(uint256 _amount)
        external
        view
        returns (uint256)
    {
        require(_amount > 0, "AMOUNT ZERO");
        uint256 totalxARDM = xARDM.totalSupply();

        return (_amount * totalxARDM) / totalARDM;
    }

    /// @notice Utility Function to get current total staking contract xARDM supply
    function getTotalxARDM() external view returns (uint256) {
        return xARDM.totalSupply();
    }

    /// @notice Utility Function to get current total staking contract ARDM supply
    function getTotalLockedARDM() external view returns (uint256) {
        return totalARDM;
    }

    /// @dev Can be only set by ADMIN
    function setPenaltyDeadline(uint256 _deadline) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_deadline != penaltyDeadline, "PENALTY DEADLINE SAME");
        uint256 oldDeadline = penaltyDeadline;
        penaltyDeadline = _deadline;
        emit PenaltyDeadlineUpdated(oldDeadline, _deadline);
    }

    /// @dev Can be only set by ADMIN
    function setPenaltyFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_fee != penaltyFee, "PENALTY FEE SAME");
        uint256 oldFee = penaltyFee;
        penaltyFee = _fee;
        emit PenaltyFeeUpdated(oldFee, _fee);
    }

    /// @dev Can be only set by ADMIN
    function setTreasuryAddress(address _treasuryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasuryAddress != treasuryAddress, "TREASURY ADDRESS SAME");
        address oldTreasuryAddress = treasuryAddress;
        treasuryAddress = _treasuryAddress;
        emit TreasuryAddressUpdated(oldTreasuryAddress, _treasuryAddress);
    }

    /// @dev Can be only set by PAUSER
    function setWithdrawPause(bool state) external onlyRole(PAUSER_ROLE) {
        require(state != withdrawPaused, "STATE SAME");
        withdrawPaused = state;
        emit WithdrawPaused(state);
    }

    /// @dev Can be only set by PAUSER
    function setDepositPause(bool state) external onlyRole(PAUSER_ROLE) {
        require(state != depositPaused, "STATE SAME");
        depositPaused = state;
        emit DepositPaused(state);
    }

    /// @dev Can be only set by PAUSER
    function setPenaltyPause(bool state) external onlyRole(PAUSER_ROLE) {
        require(state != penaltyFeePaused, "STATE SAME");
        penaltyFeePaused = state;
        emit PenaltyPaused(state);
    }

    /// @dev Utility Function to get current staker deadline
    function userDeadlineOf(address account) external view returns (uint256) {
        require(account != address(0), "ADDRESS ZERO");
        return _userDeadline[account];
    }

    /// @dev Utility Function to get current staking contract version , assuming future staking contracts will be made
    function version() external pure returns (string memory) {
        return "2";
    }
}
