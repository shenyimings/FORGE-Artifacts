// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IDeFiAIMultiStrat.sol";

contract DeFiAIFarmV2 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    /* ========== EVENTS ============= */

    event Deposit(address indexed user, uint256 amount, address wantAddress);
    event Withdraw(address indexed user, uint256 amount, address wantAddress);
    event UpdateWithdrawalFee(uint256 fee);
    event UpdateMinWithdrawalFee(uint256 pid, uint256 minFee);

    /* ========== STRUCTS ============= */

    struct UserInfo {
        string upline;
    }

    struct PoolInfo {
        IERC20 want;
        uint256 minFee;
        address strat;
    }

    /* ========== CONSTANTS ============= */

    // Denominator for fee calculations.
    uint256 public constant FEE_DENOM = 10000;

    /* ========== STATE VARIABLES ========== */

    // Info of each pool.
    PoolInfo[] public  poolInfo;
  
    // Fee paid for withdrawals
    uint256 public  withdrawalFee;

    // Developer address.
    address public devAddress;

    // Init state
    bool public isInit;

    /* ========== MODIFIERS ========== */

    modifier validatePid(uint256 _pid) {
        require(
            _pid < poolInfo.length,
            "DeFiAIFarmV2::validatePid: Not exist"
        );
        _;
    }

    modifier onlyGovernance() {
        require(
            (msg.sender == devAddress || msg.sender == owner()),
            "DeFiAIFarmV2::onlyGovernance: Not gov"
        );
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _devAddress,
        uint256 _withdrawalFee
    ) {
        devAddress = _devAddress;
        withdrawalFee = _withdrawalFee;
    }

    /* ========== VIEWS ========== */

    function poolLength() external view  returns (uint256) {
        return poolInfo.length;
    }

    function getTotalBalance(uint256 _pid, address _user) 
    external 
    view 
    validatePid(_pid) 
    returns (uint256) 
    {
        PoolInfo memory pool = poolInfo[_pid];
        return IDeFiAIMultiStrat(pool.strat).balances(_user);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function deposit(uint256 _pid, uint256 _wantAmt)
        external
        validatePid(_pid)
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        if (_wantAmt > 0) {
            pool.want.safeTransferFrom(
                address(msg.sender),
                address(this),
                _wantAmt
            );

            pool.want.safeIncreaseAllowance(pool.strat, _wantAmt);
            IDeFiAIMultiStrat(pool.strat).deposit(msg.sender, _wantAmt, address(pool.want));
        }
        emit Deposit(msg.sender, _wantAmt, address(pool.want));
    }

    function withdraw(uint256 _pid, uint256 _wantAmt)
        public
        validatePid(_pid)
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 realAmt;
        if (_wantAmt > 0) {
            realAmt = IDeFiAIMultiStrat(pool.strat).withdraw(msg.sender, _wantAmt, address(pool.want));

            _wantAmt = realAmt;
            uint256 fee = _wantAmt * withdrawalFee / FEE_DENOM;
            if (fee < pool.minFee) {
                fee = pool.minFee;
            }
            require(_wantAmt >= fee, "DeFiAIFarmV2::withdraw: _wantAmt < fee");
            _wantAmt -= fee;
            pool.want.safeTransfer(pool.strat, fee);
            pool.want.safeTransfer(address(msg.sender), _wantAmt);
        }
        emit Withdraw(msg.sender, realAmt, address(pool.want));
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    
    function initialize(
        IERC20 _want0, 
        address _strat0, 
        uint256 _minFee0, 
        IERC20 _want1, 
        address _strat1, 
        uint256 _minFee1
    ) external onlyGovernance {
        require(!isInit, "DeFiAIFarmV2::setStrats: Already initialized");
        require(_strat0 != address(0) && _strat1 != address(0), "DeFiAIFarmV2::setStrats: Strat can not be zero address.");
        poolInfo.push(
            PoolInfo({
                want: _want0,
                minFee: _minFee0,
                strat: _strat0
            })
        );
        poolInfo.push(
            PoolInfo({
                want: _want1,
                minFee: _minFee1,
                strat: _strat1
            })
        );
        isInit = true;
    }    
}
