// SPDX-License-Identifier: WTFPL License
pragma solidity >=0.6.0;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/utils/ReentrancyGuard.sol";

import "../libs/Pausable.sol";

import "../interfaces/IMasterShepherd.sol";
import "../interfaces/IStrategyShepherd.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeFarm.sol";

contract PancakeStrategyShepherd is
    Ownable,
    Pausable,
    ReentrancyGuard,
    IStrategyShepherd
{
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    IPancakeFarm public farmContract; // address of farm, eg. Pancake
    uint256 public pid; // pid of pool in farmContractAddress
    bool public isCAKEStaking; // only for staking CAKE using pancakeswap's native CAKE staking contract
    IBEP20 public lpToken;
    address public token0Addr; //lpToken token0
    address public token1Addr; //lpToken token1
    IBEP20 public farmedToken;
    address public routerAddr; // eg. pancakeswap router

    address public masterShepherdAddr;
    address public lamaTokenAddr;
    address public adminAddr;
    address public feeAddr;

    uint256 public lastEarnBlock;
    uint256 public override lpLockedTotal;

    address public constant burnAddr =
        0x000000000000000000000000000000000000dEaD;
    uint256 public constant performanceFee = 50; // 0.5%    

    address[] public farmedToLamaPath;

    address public wbnbAddr;

    event EmergencyBEP20Drain(address token, address recipient, uint256 amount);

    constructor(
        address _masterShepherdAddr,
        address _lamaTokenAddr,
        address _feeAddr,
        address _farmContractAddr,
        uint256 _pid,
        bool _isCAKEStaking,
        address _lpTokenAddr,
        address _farmedTokenAddr,
        address _routerAddr,
        address _wbnbAddr
    ) public {
        masterShepherdAddr = _masterShepherdAddr;
        lamaTokenAddr = _lamaTokenAddr;
        farmContract = IPancakeFarm(_farmContractAddr);
        pid = _pid;
        isCAKEStaking = _isCAKEStaking;
        lpToken = IBEP20(_lpTokenAddr);
        farmedToken = IBEP20(_farmedTokenAddr);
        routerAddr = _routerAddr;
        wbnbAddr = _wbnbAddr;

        adminAddr = msg.sender;
        feeAddr = _feeAddr;

        if (!isCAKEStaking) {
            token0Addr = IPancakePair(_lpTokenAddr).token0();
            token1Addr = IPancakePair(_lpTokenAddr).token1();
        }

        farmedToLamaPath = [_farmedTokenAddr, wbnbAddr, lamaTokenAddr];
        if (wbnbAddr == _farmedTokenAddr) {
            farmedToLamaPath = [wbnbAddr, lamaTokenAddr];
        }
    }

    modifier onlyAdmin {
        require(msg.sender == adminAddr, "!admin");
        _;
    }

    modifier onlyMasterShepherd {
        require(msg.sender == masterShepherdAddr, "!masterShepherd");
        _;
    }

    // Transfer LP tokens from MasterShepherd to strategy
    function deposit(uint256 _lpAmount, address)
        external
        override
        onlyMasterShepherd
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _lpAmount
        );

        lpLockedTotal = lpLockedTotal.add(_lpAmount);
        lpToken.safeIncreaseAllowance(address(farmContract), _lpAmount);

        // deposits to farm
        if (isCAKEStaking) {
            // Just for CAKE staking, we dont use deposit()
           farmContract.enterStaking(_lpAmount);
        } else {
           farmContract.deposit(pid, _lpAmount);
        }

        return _lpAmount;
    }

    // Transfer LP tokens from strategy back to MasterShepherd
    function withdraw(uint256 _lpAmount, address)
        external
        override
        onlyMasterShepherd
        nonReentrant
        returns (uint256)
    {
        require(_lpAmount > 0, "_lpAmount <= 0");

        if (isCAKEStaking) {
            // Just for CAKE staking, we dont use withdraw()
           farmContract.leaveStaking(_lpAmount);
        } else {
           farmContract.withdraw(pid, _lpAmount);
        }

        uint256 lpTokenAmt = lpToken.balanceOf(address(this));
        if (_lpAmount > lpTokenAmt) {
            _lpAmount = lpTokenAmt;
        }
        if (_lpAmount > lpLockedTotal) {
            _lpAmount = lpLockedTotal;
        }

        lpLockedTotal = lpLockedTotal.sub(_lpAmount);

        lpToken.safeTransfer(masterShepherdAddr, _lpAmount);

        return _lpAmount;
    }

    // Triggers token farming and buyback
    function earn() external override whenNotPaused {
        // Harvest farm tokens
        if (isCAKEStaking) {
            // Just for CAKE staking, we dont use withdraw()
            farmContract.leaveStaking(0);
        } else {
            farmContract.withdraw(pid, 0);
        }

        // Converts farm tokens into lpTokens
        uint256 farmedAmt = farmedToken.balanceOf(address(this));
        uint256 fee = farmedAmt.mul(performanceFee).div(10000);
        farmedToken.safeTransfer(feeAddr, fee);
        farmedAmt = farmedAmt.sub(fee);
        buyBackAndBurn(farmedAmt);

        lastEarnBlock = block.number;
    }

    function buyBackAndBurn(uint256 _buybackAmt) internal {
        farmedToken.safeIncreaseAllowance(routerAddr, _buybackAmt);

        IPancakeRouter02(routerAddr)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _buybackAmt,
            0,
            farmedToLamaPath,
            burnAddr,
            now + 600
        );
    }

    function drainStuckToken(address _token) external override onlyAdmin {
        require(_token != address(lpToken), "!safe");
        require(_token != address(farmedToken), "!safe");
        IBEP20 token = IBEP20(_token);
        uint256 amount = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);
        emit EmergencyBEP20Drain(address(token), msg.sender, amount);
    }

    function setAdmin(address _newAdmin) external onlyAdmin {
        adminAddr = _newAdmin;
    }

    function setFeeAddr(address _newFeeAddr) external onlyAdmin {
        feeAddr = _newFeeAddr;
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unpause() external onlyAdmin {
        _unpause();
    }
}
