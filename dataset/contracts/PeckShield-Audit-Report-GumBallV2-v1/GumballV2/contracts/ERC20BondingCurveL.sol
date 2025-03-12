// SPDX-License-Identifier: MIT

//   ██████╗ ██╗   ██╗███╗   ███╗██████╗  █████╗ ██╗     ██╗        ███████╗██╗
//  ██╔════╝ ██║   ██║████╗ ████║██╔══██╗██╔══██╗██║     ██║        ██╔════╝██║
//  ██║  ███╗██║   ██║██╔████╔██║██████╔╝███████║██║     ██║        █████╗  ██║
//  ██║   ██║██║   ██║██║╚██╔╝██║██╔══██╗██╔══██║██║     ██║        ██╔══╝  ██║
//  ╚██████╔╝╚██████╔╝██║ ╚═╝ ██║██████╔╝██║  ██║███████╗███████╗██╗██║     ██║
//   ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝     ╚═╝
                                                                                                                                                
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IFactory {
    function getOwner() external view returns (address);
}

interface IGumbar {
    function balanceOf(address account) external view returns (uint256);
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external; 
}

contract ERC20BondingCurveL is ERC20Upgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Bonding Curve Variables
    address public BASE_TOKEN;

    uint256 public reserveVirtualBASE;
    uint256 public reserveRealBASE;
    uint256 public reserveGBT;

    uint256 public initial_totalSupply;

    uint256 public treasuryBASE;
    uint256 public treasuryGBT;

    address public gumball;
    address public gumbar;
    address public artist;
    address public protocol;
    address public factory;
    address public treasury;

    uint256 start;
    uint256 delay;

    // Fee
    uint256 constant PROTOCOL = 25;
    uint256 constant TREASURY = 200;
    uint256 constant GUMBAR = 400;
    uint256 constant ARTIST = 400;
    uint256 constant DIVISOR = 1000;

    // Borrow Variables
    uint256 public borrowedTotalBASE;

    mapping(address => uint256) public borrowedBASE;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public limit;

    // Events

    event Buy(address indexed user, uint256 amount);
    event Sell(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Skim(address indexed user);
    event UpdateOwnership(address newOwner);
    event SetTreasury(address newTreasury);
    event ChangeArtist(address newArtist);

    function initialize(
        string memory __name,
        string memory __symbol,
        address _baseToken,
        uint256 _initialVirtualBASE,
        uint256 _supplyGBT,
        address _gumball,
        address _gumbar,
        address _artist,
        uint256 _delay
    ) public initializer {
        __ERC20_init(__name, __symbol);

        BASE_TOKEN = _baseToken;
        gumball = _gumball;
        gumbar = _gumbar;
        artist = _artist;

        reserveVirtualBASE = _initialVirtualBASE;

        reserveRealBASE = 0;
        initial_totalSupply = _supplyGBT;
        reserveGBT = _supplyGBT;

        start = block.timestamp;
        delay = _delay;
        protocol = IFactory(msg.sender).getOwner();
        factory = msg.sender;
        treasury = protocol;

        _mint(address(this), _supplyGBT);
    }

    //////////////////
    ///// Public /////
    //////////////////

    /** @dev returns the current price of {GBT} */
    function currentPrice() public view returns (uint256) {
        return ((reserveVirtualBASE + reserveRealBASE) * 1e18) / reserveGBT;
    }

    /** @dev returns the allowance @param user can borrow */
    function borrowCredit(address account) public view returns (uint256) {
        uint256 borrowPowerGBT = IGumbar(gumbar).balanceOf(account);
        if (borrowPowerGBT == 0) {
            return 0;
        }
        uint256 borrowTotalBASE = (reserveVirtualBASE * totalSupply() / (totalSupply() - borrowPowerGBT)) - reserveVirtualBASE;
        uint256 borrowableBASE = borrowTotalBASE - borrowedBASE[account];
        return borrowableBASE;
    }

    function skimReward() public view returns (uint256) {
        return treasuryBASE * 10 / 10000;
    }

    /** @dev returns amount borrowed by @param user */
    function debt(address account) public view returns (uint256) {
        return borrowedBASE[account];
    }

    function baseBal() public view returns (uint256) {
        return IERC20Upgradeable(BASE_TOKEN).balanceOf(address(this));
    }

    function gbtBal() public view returns (uint256) {
        return IERC20Upgradeable(address(this)).balanceOf(address(this));
    }

    function getProtocol() public view returns (address) {
        return protocol;
    }

    function getGumball() public view returns (address) {
        return gumball;
    }

    function initSupply() public view returns (uint256) {
        return initial_totalSupply;
    }

    function floorPrice() public view returns (uint256) {
        return (reserveVirtualBASE * 1e18) / totalSupply();
    }

    function mustStayGBT(address account) public view returns (uint256) {
        uint256 accountBorrowedBASE = borrowedBASE[account];
        if (accountBorrowedBASE == 0) {
            return 0;
        }
        uint256 amount = totalSupply() - (reserveVirtualBASE * totalSupply() / (accountBorrowedBASE + reserveVirtualBASE));
        return amount;
    }
 
    ////////////////////
    ///// External /////
    ////////////////////

    /** @dev Buy function.  User spends {BASE} and receives {GBT}
      * @param _amountBASE is the amount of the {BASE} being spent
      * @param _minGBT is the minimum amount of {GBT} out
      * @param expireTimestamp is the expire time on txn
      *
      * If a delay was set on the proxy deployment and has not elapsed:
      *     1. the user must be whitelisted by the protocol to call the function
      *     2. the whitelisted user cannont buy more than 1 GBT until the delay has elapsed
    */
    function buy(uint256 _amountBASE, uint256 _minGBT, uint256 expireTimestamp) public nonReentrant {
        require(start + delay <= block.timestamp || whitelist[msg.sender], "Market Closed");
        require(expireTimestamp == 0 || expireTimestamp > block.timestamp, "Expired");

        address account = msg.sender;

        syncReserves();
        uint256 feeAmountBASE = _amountBASE * PROTOCOL / DIVISOR;
        treasuryBASE += (feeAmountBASE);

        uint256 oldReserveBASE = reserveVirtualBASE + reserveRealBASE;
        uint256 newReserveBASE = oldReserveBASE + _amountBASE - feeAmountBASE;

        uint256 oldReserveGBT = reserveGBT;
        uint256 newReserveGBT = oldReserveBASE * oldReserveGBT / newReserveBASE;

        uint256 outGBT = oldReserveGBT - newReserveGBT;

        require(outGBT > _minGBT, "Less than Min");

        if (start + delay >= block.timestamp) {
            require(outGBT <= 10e18 && limit[account] <= 10e18, "Over whitelist limit");
            limit[account] += outGBT;
            require(limit[account] <= 10e18, "Whitelist amount overflow");
        }

        reserveRealBASE = newReserveBASE - reserveVirtualBASE;
        reserveGBT = newReserveGBT;

        IERC20Upgradeable(BASE_TOKEN).safeTransferFrom(account, address(this), _amountBASE);
        IERC20Upgradeable(address(this)).safeTransfer(account, outGBT);

        emit Buy(account, _amountBASE);
    }

    /** @dev Sell function.  User sells their {GBT} token for {BASE}
      * @param _amountGBT is the amount of {GBT} in
      * @param _minETH is the minimum amount of {ETH} out 
      * @param expireTimestamp is the expire time on txn
    */
    function sell(uint256 _amountGBT, uint256 _minETH, uint256 expireTimestamp) external nonReentrant {
        require(expireTimestamp == 0 || expireTimestamp > block.timestamp, "Expired");

        address account = msg.sender;

        syncReserves();
        uint256 feeAmountGBT = _amountGBT * PROTOCOL / DIVISOR;
        treasuryGBT += feeAmountGBT;

        uint256 oldReserveGBT = reserveGBT;
        uint256 newReserveGBT = reserveGBT + _amountGBT - feeAmountGBT;

        uint256 oldReserveBASE = reserveVirtualBASE + reserveRealBASE;
        uint256 newReserveBASE = oldReserveBASE * oldReserveGBT / newReserveGBT;

        uint256 outBASE = oldReserveBASE - newReserveBASE;

        require(outBASE > _minETH, "Less than Min");

        reserveRealBASE = newReserveBASE - reserveVirtualBASE;
        reserveGBT = newReserveGBT;

        IERC20Upgradeable(address(this)).safeTransferFrom(account, address(this), _amountGBT);
        IERC20Upgradeable(BASE_TOKEN).safeTransfer(account, outBASE);

        emit Sell(account, _amountGBT);
    }

    /** @dev Distributes fees according to their weights.  Rewards the caller 0.1% of {treasuryBASE} */
    function treasurySkim() external {
        uint256 _treasuryGBT = treasuryGBT;
        uint256 _treasuryBASE = treasuryBASE;

        // Reward for the caller
        uint256 reward = _treasuryBASE * 10 / 10000;   // 0.1%
        _treasuryBASE -= reward;

        treasuryBASE = 0;
        treasuryGBT = 0;

        // requires here 
        IERC20Upgradeable(address(this)).safeApprove(gumbar, 0);
        IERC20Upgradeable(address(this)).safeApprove(gumbar, _treasuryGBT * GUMBAR / DIVISOR);
        IGumbar(gumbar).notifyRewardAmount(address(this), _treasuryGBT * GUMBAR / DIVISOR);
        IERC20Upgradeable(address(this)).safeTransfer(artist, _treasuryGBT * ARTIST / DIVISOR);
        IERC20Upgradeable(address(this)).safeTransfer(treasury, _treasuryGBT * TREASURY / DIVISOR);

        // requires here
        IERC20Upgradeable(BASE_TOKEN).safeApprove(gumbar, 0);
        IERC20Upgradeable(BASE_TOKEN).safeApprove(gumbar, _treasuryBASE * GUMBAR / DIVISOR);
        IGumbar(gumbar).notifyRewardAmount(BASE_TOKEN, _treasuryBASE * GUMBAR / DIVISOR);
        IERC20Upgradeable(BASE_TOKEN).safeTransfer(artist, _treasuryBASE * ARTIST / DIVISOR);
        IERC20Upgradeable(BASE_TOKEN).safeTransfer(treasury, _treasuryBASE * TREASURY / DIVISOR);
        IERC20Upgradeable(BASE_TOKEN).safeTransfer(msg.sender, reward);

        emit Skim(msg.sender);
    }

    /** @dev User borrows an amount of {BASE} equal to @param _amount */
    function borrowSome(uint256 _amount) external nonReentrant {
        require(_amount > 0, "!Zero");

        address account = msg.sender;

        uint256 borrowPowerGBT = IGumbar(gumbar).balanceOf(account);

        uint256 borrowTotalBASE = (reserveVirtualBASE * totalSupply() / (totalSupply() - borrowPowerGBT)) - reserveVirtualBASE;
        uint256 borrowableBASE = borrowTotalBASE - borrowedBASE[account];

        require(borrowableBASE >= _amount, "Borrow Underflow");

        borrowedBASE[account] += _amount;
        borrowedTotalBASE += _amount;

        IERC20Upgradeable(BASE_TOKEN).safeTransfer(account, _amount);

        emit Borrow(account, _amount);
    }

    /** @dev User borrows the maximum amount of {BASE} their locked {XGBT} will allow */
    function borrowMax() external nonReentrant {

        address account = msg.sender;

        uint256 borrowPowerGBT = IGumbar(gumbar).balanceOf(account);

        uint256 borrowTotalBASE = (reserveVirtualBASE * totalSupply() / (totalSupply() - borrowPowerGBT)) - reserveVirtualBASE;
        uint256 borrowableBASE = borrowTotalBASE - borrowedBASE[account];

        borrowedBASE[account] += borrowableBASE;
        borrowedTotalBASE += borrowableBASE;

        IERC20Upgradeable(BASE_TOKEN).safeTransfer(account, borrowableBASE);

        emit Borrow(account, borrowableBASE);
    }

    /** @dev User repays a portion of their debt equal to @param _amount */
    function repaySome(uint256 _amount) external nonReentrant {
        require(_amount > 0, "!Zero");

        address account = msg.sender;
        
        borrowedBASE[account] -= _amount;
        borrowedTotalBASE -= _amount;

        IERC20Upgradeable(BASE_TOKEN).safeTransferFrom(account, address(this), _amount);

        emit Repay(account, _amount);
    }

    /** @dev User repays their debt and opens unlocking of {XGBT} */
    function repayMax() external nonReentrant {

        address account = msg.sender;

        uint256 amountRepayBASE = borrowedBASE[account];
        borrowedBASE[account] = 0;
        borrowedTotalBASE -= amountRepayBASE;

        IERC20Upgradeable(BASE_TOKEN).safeTransferFrom(account, address(this), amountRepayBASE);

        emit Repay(account, amountRepayBASE);
    }

    /** @dev Protocol function to add or remove users from whitelist 
      * @param accounts is the address added/removed
      * @param _bool is true/false
    */
    function _whitelist(address[] memory accounts, bool _bool) external onlyProtocol() {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = _bool;
        }
    }

    function updateOwnership() external onlyProtocol() {
       protocol = IFactory(factory).getOwner();
       emit UpdateOwnership(protocol);
    }

    function setTreasury(address _treasuryAddr) external onlyProtocol() {
        treasury = _treasuryAddr;
        emit SetTreasury(_treasuryAddr);
    }

    function changeArtist(address _newArtistAddr) external onlyArtist() {
        artist = _newArtistAddr;
        emit ChangeArtist(_newArtistAddr);
    }

    ////////////////////
    ///// Internal /////
    ////////////////////

    /** @dev Remove yield and rebalance */
    function syncReserves() internal {
        uint256 baseBalance = IERC20Upgradeable(BASE_TOKEN).balanceOf(address(this)) + borrowedTotalBASE;
        if(baseBalance > reserveRealBASE + treasuryBASE) {
            treasuryBASE += (baseBalance - reserveRealBASE - treasuryBASE);
        }
        uint256 gbtBalance = IERC20Upgradeable(address(this)).balanceOf(address(this));
        if (gbtBalance > reserveGBT + treasuryGBT) {
            treasuryGBT += (gbtBalance - reserveGBT - treasuryGBT);
        }
    }

    ////////////////////
    ///// Modifier /////
    ////////////////////
 
    modifier onlyProtocol() {
        require(msg.sender == protocol, "!Authorized");
        _;
    }

    modifier onlyArtist() {
        require(msg.sender == artist, "!Authorized");
        _;
    }
}