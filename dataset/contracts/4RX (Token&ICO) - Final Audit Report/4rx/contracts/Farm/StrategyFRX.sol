//SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract StrategyFrx is Ownable, ReentrancyGuard, Pausable {
    // Strategy used to only stake frx tokens

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool public isCAKEStaking; // always set to FALSE
    bool public isFrxVault; // always set to FALSE

    address public farmContractAddress; // not used, funds stay on strategy address
    uint256 public pid; // not used
    address public wantAddress;
    address public token0Address; // not used
    address public token1Address; // not used
    address public earnedAddress;
    address public uniRouterAddress; // not used, no buyback

    address public constant wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // not used
    address public frxFarmAddress;
    address public FRXAddress;
    address public govAddress; // timelock contract
    bool public onlyGov = true;

    uint256 public lastEarnBlock = 0;
    uint256 public wantLockedTotal = 0;
    uint256 public sharesTotal = 0;

    uint256 public controllerFee = 20;
    uint256 public constant controllerFeeMax = 10000; // 100 = 1%
    uint256 public constant controllerFeeUL = 300;

    // not used, no buyback
    uint256 public buyBackRate = 150; // not used
    uint256 public constant buyBackRateMax = 10000; // not used
    uint256 public constant buyBackRateUL = 800; // not used

    /* This is vanity address -  For instance an address 0x000000000000000000000000000000000000dEaD for which it's
       absolutely impossible to generate a private key with today's computers. */
    address public constant buyBackAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public entranceFeeFactor = 9990; // < 0.1% entrance fee - goes to pool + prevents front-running
    uint256 public constant entranceFeeFactorMax = 10000;
    uint256 public constant entranceFeeFactorLL = 9950; // 0.5% is the max entrance fee settable. LL = lowerlimit

    address[] public earnedToFRXPath; // not used
    address[] public earnedToToken0Path; // not used
    address[] public earnedToToken1Path; // not used
    address[] public token0ToEarnedPath; // not used
    address[] public token1ToEarnedPath; // not used

    constructor(
        address _frxFarmAddress,
        address _FRXAddress,
        bool _isCAKEStaking,
        bool _isFrxVault,
        address _farmContractAddress,
        uint256 _pid,
        address _wantAddress,
        address _token0Address,
        address _token1Address,
        address _earnedAddress,
        address _uniRouterAddress
    ) public {
        govAddress = msg.sender;
        frxFarmAddress = _frxFarmAddress;
        FRXAddress = _FRXAddress;

        isCAKEStaking = _isCAKEStaking;
        isFrxVault = _isFrxVault;
        wantAddress = _wantAddress;
        farmContractAddress = _farmContractAddress;
        pid = _pid;
        token0Address = _token0Address;
        token1Address = _token1Address;
        earnedAddress = _earnedAddress;
        uniRouterAddress = _uniRouterAddress;

        transferOwnership(frxFarmAddress);
    }

    // Receives new deposits from user
    function deposit(address _userAddress, uint256 _wantAmt)
    public
    onlyOwner
    whenNotPaused
    returns (uint256)
    {
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal > 0) {
            sharesAdded = _wantAmt
            .mul(sharesTotal)
            .mul(entranceFeeFactor)
            .div(wantLockedTotal)
            .div(entranceFeeFactorMax);

            // Fix if pool stuck
            if (sharesAdded == 0 && sharesTotal == 0) {
                sharesAdded = _wantAmt
                .mul(entranceFeeFactor)
                .div(wantLockedTotal)
                .div(entranceFeeFactorMax);
            }
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        if (isFrxVault) {
            _farm();
        } else {
            wantLockedTotal = wantLockedTotal.add(_wantAmt);
        }

        return sharesAdded;
    }

    function farm() public nonReentrant {
        _farm();
    }

    // not used
    function _farm() internal {}

    function withdraw(address _userAddress, uint256 _wantAmt) public onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "_wantAmt <= 0");

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal);
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);
        wantLockedTotal = wantLockedTotal.sub(_wantAmt);

        IERC20(wantAddress).safeTransfer(frxFarmAddress, _wantAmt);

        return sharesRemoved;
    }

    // not used
    function earn() public whenNotPaused {}
    // not used
    function buyBack(uint256 _earnedAmt) internal returns (uint256) {}
    // not used
    function distributeFees(uint256 _earnedAmt) internal returns (uint256) {}
    // not used
    function convertDustToEarned() public whenNotPaused {}

    function pause() public {
        require(msg.sender == govAddress, "Not authorised");
        _pause();
    }

    function unpause() external {
        require(msg.sender == govAddress, "Not authorised");
        _unpause();
    }

    function setEntranceFeeFactor(uint256 _entranceFeeFactor) public {
        require(msg.sender == govAddress, "Not authorised");
        require(_entranceFeeFactor > entranceFeeFactorLL, "!safe - too low");
        require(_entranceFeeFactor <= entranceFeeFactorMax, "!safe - too high");
        entranceFeeFactor = _entranceFeeFactor;
    }

    function setControllerFee(uint256 _controllerFee) public {
        require(msg.sender == govAddress, "Not authorised");
        require(_controllerFee <= controllerFeeUL, "too high");
        controllerFee = _controllerFee;
    }

    function setbuyBackRate(uint256 _buyBackRate) public {
        require(msg.sender == govAddress, "Not authorised");
        require(buyBackRate <= buyBackRateUL, "too high");
        buyBackRate = _buyBackRate;
    }

    function setGov(address _govAddress) public {
        require(msg.sender == govAddress, "!gov");
        govAddress = _govAddress;
    }

    function setOnlyGov(bool _onlyGov) public {
        require(msg.sender == govAddress, "!gov");
        onlyGov = _onlyGov;
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) public {
        require(msg.sender == govAddress, "!gov");
        require(_token != earnedAddress, "!safe");
        require(_token != wantAddress, "!safe");
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
