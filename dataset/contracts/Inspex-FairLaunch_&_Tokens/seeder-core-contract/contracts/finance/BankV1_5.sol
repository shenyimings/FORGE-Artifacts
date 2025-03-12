// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "../utils/SafeMath.sol";
import "../utils/Loanable.sol";
import "../wallet/PlatformWallet.sol";


contract BankV1_5 is Loanable {
    using SafeMath for uint256;

    event DepositNative(address indexed depositor, uint256 depositAmount, uint256 ibAmount);
    event WithdrawNative(address indexed depositor, address indexed ibToken, uint256 ibAmount, uint256 withdrawnAmount);

    event Deposit(address indexed depositor, address indexed depositToken, address indexed ibToken, uint256 depositAmount, uint256 ibAmount);
    event Withdraw(address indexed depositor, address indexed ibToken, address indexed withdrawnToken, uint256 ibAmount, uint256 withdrawnAmount);

    event BorrowNative(address indexed loanIssuer, address indexed targetAccount, uint256 amount);
    event PaybackNative(address indexed payer, uint256 paybackAmount);

    event Borrow(address indexed loanIssuer, address indexed targetAccount, address indexed borrowToken, uint256 amount);
    event Payback(address indexed payer, address indexed borrowToken, uint256 paybackAmount);

    struct DepositPair {
        IERC20 originToken;
        IERC20 ibToken;
        uint256 originBorrowAmount;
    }

    uint256 constant CALCULATE_PRECISION = 1E18;

    IERC20 private _ibNativeToken;
    uint256 private _totalBorrowNativeOrigin;
    
    uint256 private _depositFeeMultiplyer;
    uint256 private _depositFeeDivider;

    uint256 private _withdrawFeeMultiplyer;
    uint256 private _withdrawFeeDivider;

    uint256 private _platformFeeMultiplyer;
    uint256 private _platformFeeDivider;

    address payable public platformAddress;

    // origin => DepositPair
    mapping(address => DepositPair) private _tokenDepositPairs; 
    address[] private _supportOriginTokens;

    function initialize(address ibNativeToken, address payable platformAddr) external initializer {
        _ibNativeToken = IERC20(ibNativeToken);

        __Loanable_init_chained();

        platformAddress = platformAddr;

        _setDepositFeeRate(2, 100);
        _setWithdrawFeeRate(2, 100);
        _setPlatformFeeDividendRate(90, 100); // For Dev 20%, Burn 70%
    }

    function getIBNativeToken() external view returns (address) {
        return address(_ibNativeToken);
    }

    function getTotalNativeToken() external view returns (uint256) {
        return _getTotalNativeBalance();
    }

    // @notice This function will be applicable when our platform implement loan feature and of course it's come when audited
    // @dev now only return value that declared without any update
    function getTotalBorrowingNativeToken() external view returns (uint256) {
        return _totalBorrowNativeOrigin;
    }

    function getTotalToken(address originToken) external view returns (uint256) {
        DepositPair memory depositPair = _tokenDepositPairs[originToken];
        require(address(depositPair.originToken) != address(0), "Not support token");

        return _getTotalTokenBalance(depositPair);
    }

    // @notice This function will be applicable when our platform implement loan feature and of course it's come when audited
    // @dev now only return value that declared without any update
    function getTotalBorrow(address originToken) external view returns (uint256) {
        DepositPair memory depositPair = _tokenDepositPairs[originToken];
        require(address(depositPair.originToken) != address(0), "Not support token");

        return depositPair.originBorrowAmount;
    }

    function getNativeIBPrice() external view returns (uint256 ibPriceWithPrecision, uint256 precision) {
        uint256 totalOrigin = _getTotalNativeBalance();
        uint256 totalIB = _ibNativeToken.totalSupply();

        (ibPriceWithPrecision, precision) = _getIBPrice(totalOrigin, totalIB);
    }

    function getIBPrice(address originToken) external view returns (uint256 ibPriceWithPrecision, uint256 precision) {
        uint256 totalOrigin;
        uint256 totalIB;

        DepositPair memory depositPair = _tokenDepositPairs[originToken];
        require(address(depositPair.originToken) != address(0), "Not support origin token");

        totalOrigin = depositPair.originToken.balanceOf(address(this));
        totalIB = depositPair.ibToken.totalSupply();

        (ibPriceWithPrecision, precision) = _getIBPrice(totalOrigin, totalIB);
    }

    function getDepositPairs() external view returns (DepositPair[] memory) {
        DepositPair[] memory response = new DepositPair[](_supportOriginTokens.length);

        for (uint256 index = 0; index < _supportOriginTokens.length; index++) {
            address originToken = _supportOriginTokens[index];
            response[index] = _tokenDepositPairs[originToken];
        }

        return response;
    }

    function depositWithNative() external payable {
        address depositor = msg.sender;
        uint256 depositAmount = msg.value;
        require(depositAmount >= 1E15, "The amount must be more than or equal 1E15");
        
        uint256 totalOrigin = _getTotalNativeBalance().sub(depositAmount); // We need total supply excluding depositing balance
        uint256 totalIB = _ibNativeToken.totalSupply();

        uint256 ibTokenAmount;
        uint256 originTokenFee;
        (ibTokenAmount, originTokenFee) = _calculateDeposit(totalOrigin, totalIB, depositAmount);
        uint256 originTokenPlatformFee = originTokenFee.mul(_platformFeeMultiplyer).div(_platformFeeDivider);
        
        platformAddress.transfer(originTokenPlatformFee);

        (bool success, bytes memory result) = address(_ibNativeToken).call(abi.encodeWithSignature("mint(address,uint256)", depositor, ibTokenAmount));
        require(success, string(result));

        emit DepositNative(depositor, depositAmount, ibTokenAmount);
    }

    function deposit(address depositOriginToken, uint256 originTokenAmount) external {
        address depositor = msg.sender;
        require(originTokenAmount >= 1E15, "The amount must be more than or equal 1E15");

        DepositPair memory depositPair = _tokenDepositPairs[depositOriginToken];
        require(address(depositPair.originToken) != address(0), "Not support token");

        uint256 totalOrigin = depositPair.originToken.balanceOf(address(this));
        uint256 totalIB = depositPair.ibToken.totalSupply();

        uint256 ibTokenAmount;
        uint256 originTokenFee;
        (ibTokenAmount, originTokenFee) = _calculateDeposit(totalOrigin, totalIB, originTokenAmount);
        uint256 originTokenPlatformFee = originTokenFee.mul(_platformFeeMultiplyer).div(_platformFeeDivider);

        depositPair.originToken.transferFrom(depositor, address(this), originTokenAmount);
        depositPair.originToken.transfer(platformAddress, originTokenPlatformFee);

        (bool success, bytes memory result) = address(depositPair.ibToken).call(abi.encodeWithSignature("mint(address,uint256)", depositor, ibTokenAmount));
        require(success, string(result));

        emit Deposit(depositor, address(depositPair.originToken), address(depositPair.ibToken), originTokenAmount, ibTokenAmount);
    }

    function withdrawNative(uint256 ibTokenAmount) external {
        
        uint256 totalOrigin = _getTotalNativeBalance();
        uint256 totalIB = _ibNativeToken.totalSupply();

        uint256 originalTokenAmount;
        uint256 originTokenFee;
        (originalTokenAmount, originTokenFee) = _calculateWithdraw(totalOrigin, totalIB, ibTokenAmount);

        require(totalOrigin >= originalTokenAmount.add(originTokenFee), "Insufficient available balance for withdraw due to the borrowing");

        address addr = address(_ibNativeToken);
        (bool success, bytes memory result) = addr.call(abi.encodeWithSignature("burn(address,uint256)", msg.sender, ibTokenAmount));
        require(success, string(result));

        uint256 originTokenPlatformFee = originTokenFee.mul(_platformFeeMultiplyer).div(_platformFeeDivider);
        
        payable(msg.sender).transfer(originalTokenAmount);
        platformAddress.transfer(originTokenPlatformFee);

        emit WithdrawNative(msg.sender, address(_ibNativeToken), ibTokenAmount, originalTokenAmount);
    }

    function withdraw(address asOriginToken, uint256 ibTokenAmount) external {
        
        uint256 totalOrigin;
        uint256 totalIB;

        DepositPair memory depositPair = _tokenDepositPairs[asOriginToken];
        require(address(depositPair.originToken) != address(0), "Not support token");
        IERC20 originToken = depositPair.originToken;
        IERC20 ibToken = depositPair.ibToken;

        totalOrigin = originToken.balanceOf(address(this));
        totalIB = ibToken.totalSupply();

        uint256 originalTokenAmount;
        uint256 originTokenFee;
        (originalTokenAmount, originTokenFee) = _calculateWithdraw(totalOrigin, totalIB, ibTokenAmount);

        require(totalOrigin >= originalTokenAmount.add(originTokenFee), "Insufficient available balance for withdraw due to the borrowing");

        address addr = address(ibToken);
        (bool success, bytes memory result) = addr.call(abi.encodeWithSignature("burn(address,uint256)", msg.sender, ibTokenAmount));
        require(success, string(result));

        uint256 originTokenPlatformFee = originTokenFee.mul(_platformFeeMultiplyer).div(_platformFeeDivider);

        originToken.transfer(msg.sender, originalTokenAmount);
        originToken.transfer(platformAddress, originTokenPlatformFee);

        emit Withdraw(msg.sender, address(depositPair.ibToken), address(depositPair.originToken), ibTokenAmount, originalTokenAmount);
    }

    // @notice This function will be applicable when our platform implement loan feature and of course it's come when audited
    function borrowNative(address payable targetAccount, uint256 amount) external onlyLoanIssuer {
    
        // require(targetAccount != address(0), "Cannot borrow to zero address");
        // require(amount >= 1E15, "The amount must be more than or equal 1E15");

        // uint256 availableBalance = address(this).balance;
        // require(amount <= availableBalance, "Insufficient balance for borrowing");

        // _totalBorrowNativeOrigin = _totalBorrowNativeOrigin.add(amount);
        // targetAccount.transfer(amount);

        // emit BorrowNative(msg.sender, targetAccount, amount);
    }

    // @notice This function will be applicable when our platform implement loan feature and of course it's come when audited
    function borrow(address borrowOriginToken, address targetAccount, uint256 amount) external onlyLoanIssuer {
        // require(targetAccount != address(0), "Cannot borrow to zero address");
        // require(amount >= 1E15, "The amount must be more than or equal 1E15");

        // DepositPair storage depositPair = _tokenDepositPairs[borrowOriginToken];
        // require(address(depositPair.originToken) != address(0), "Not support token");

        // uint256 availableBalance = depositPair.originToken.balanceOf(address(this));
        // require(amount <= availableBalance, "Insufficient balance for borrowing");

        // depositPair.originBorrowAmount = depositPair.originBorrowAmount.add(amount);
        // depositPair.originToken.transfer(targetAccount, amount);

        // emit Borrow(msg.sender, targetAccount, borrowOriginToken, amount);
    }

    // @notice This function will be applicable when our platform implement loan feature and of course it's come when audited
    function payBackNative(uint256 payBackBalance, uint256 fee) external payable {
        // uint256 totalBalance = msg.value;
        // require(totalBalance == payBackBalance.add(fee), "Total balance not match with parameters");

        // uint256 platformFee = fee.mul(_platformFeeMultiplyer).div(_platformFeeDivider);
        // platformAddress.transfer(platformFee);

        // _totalBorrowNativeOrigin = _totalBorrowNativeOrigin.sub(payBackBalance);

        // emit PaybackNative(msg.sender, payBackBalance);
    }

    // @notice This function will be applicable when our platform implement loan feature and of course it's come when audited
    function payBack(address originToken, uint256 payBackBalance, uint256 fee) external {
        // DepositPair storage depositPair = _tokenDepositPairs[originToken];
        // require(address(depositPair.originToken) != address(0), "Not support token");
        
        // uint256 totalBalance = payBackBalance.add(fee);
        // depositPair.originToken.transferFrom(msg.sender, address(this), totalBalance);

        // uint256 platformFee = fee.mul(_platformFeeMultiplyer).div(_platformFeeDivider);
        // depositPair.originToken.transfer(platformAddress, platformFee);

        // depositPair.originBorrowAmount = depositPair.originBorrowAmount.sub(payBackBalance);

        // emit Payback(msg.sender, originToken, payBackBalance);
    }

    // @notice This function will be applicable when our platform implement loan feature and of course it's come when audited
    // @dev now only return value that declared without any update
    function getTotalBorrowNativeOrigin() external view returns (uint256) {
        return _totalBorrowNativeOrigin;
    }

    function getDepositFeeRate() external view returns (uint256, uint256) {
        return (_depositFeeMultiplyer, _depositFeeDivider);
    }

    function getWithdrawFeeRate() external view returns (uint256, uint256) {
        return (_withdrawFeeMultiplyer, _withdrawFeeDivider);
    }

    function getPlatformFeeDividendRate() external view returns (uint256, uint256) {
        return (_platformFeeMultiplyer, _platformFeeDivider);
    }

    //===============================
    // Owner Method
    //===============================

    function addDepositPair(address originTokenAddress, address ibTokenAddress) external onlyOwner {
        require(originTokenAddress != address(0), "Cannot add zero address in the pairs");
        require(ibTokenAddress != address(0), "Cannot add zero address in the pairs");
        require(address(_ibNativeToken) != ibTokenAddress, "Cannot add existing ibToken");

        DepositPair storage depositPair = _tokenDepositPairs[originTokenAddress];
        require(address(depositPair.originToken) == address(0), "Cannot add existing ibToken");

        depositPair.originToken = IERC20(originTokenAddress);
        depositPair.ibToken = IERC20(ibTokenAddress);
        
        _supportOriginTokens.push(originTokenAddress);
    }

    function setDepositFeeRate(uint256 multiplyer, uint256 divider) external onlyOwner  {
        _setDepositFeeRate(multiplyer, divider);
    }

    function setWithdrawFeeRate(uint256 multiplyer, uint256 divider) external onlyOwner {
        _setWithdrawFeeRate(multiplyer, divider);
    }

    function setPlatformAddress(address payable platformAddr) external onlyOwner {
        platformAddress = platformAddr;
    }

    function setPlatformFeeDividendRate(uint256 multiplyer, uint256 divider) external onlyOwner  {
        _setPlatformFeeDividendRate(multiplyer, divider);
    }


    //===============================
    // Private method
    //===============================

    function _calculateDeposit(uint256 totalOrigin, uint256 totalIB, uint256 depositOrigin) private view returns (uint256, uint256) {
        uint256 originFee;
        if (depositOrigin <= _depositFeeDivider) {
            originFee = _depositFeeMultiplyer;
        } else {
            originFee = depositOrigin.mul(_depositFeeMultiplyer).div(_depositFeeDivider);
        }

        uint256 originExcludeFee = depositOrigin.sub(originFee);

        uint256 ibPriceWithPrecision;
        uint256 pricePrecision;
        (ibPriceWithPrecision, pricePrecision) = _getIBPrice(totalOrigin, totalIB);
        uint256 ib = originExcludeFee.mul(pricePrecision).div(ibPriceWithPrecision);

        return (ib, originFee);
    }

    function _calculateWithdraw(uint256 totalOrigin, uint256 totalIB, uint256 withdrawIB) private view returns (uint256, uint256) {
        uint256 ibPriceWithPrecision;
        uint256 pricePrecision;
        (ibPriceWithPrecision, pricePrecision) = _getIBPrice(totalOrigin, totalIB);

        uint256 origin = withdrawIB.mul(ibPriceWithPrecision).div(pricePrecision);

        uint256 originFee;
        if (origin <= _withdrawFeeDivider) {
            originFee = _withdrawFeeMultiplyer;
        } else {
            originFee = origin.mul(_withdrawFeeMultiplyer).div(_withdrawFeeDivider);
        }

        return (origin.sub(originFee), originFee);
    }

    function _getIBPrice(uint256 totalOrigin, uint256 totalIB) private pure returns (uint256 ibPriceWithPrecision, uint256 precision) {
        (ibPriceWithPrecision, precision) = (totalOrigin == 0 || totalIB == 0) ? (CALCULATE_PRECISION, CALCULATE_PRECISION) : (totalOrigin.mul(CALCULATE_PRECISION).div(totalIB), CALCULATE_PRECISION);
    }

    function _setDepositFeeRate(uint256 multiplyer, uint256 divider) private  {
        require(multiplyer <= divider, "Fee multiplyer cannot be exceed divider");

        _depositFeeMultiplyer = multiplyer;
        _depositFeeDivider = divider;
    }

    function _setWithdrawFeeRate(uint256 multiplyer, uint256 divider) private  {
        require(multiplyer <= divider, "Fee multiplyer cannot be exceed divider");

        _withdrawFeeMultiplyer = multiplyer;
        _withdrawFeeDivider = divider;
    }

    function _setPlatformFeeDividendRate(uint256 multiplyer, uint256 divider) private   {
        require(multiplyer <= divider, "Fee multiplyer cannot be exceed divider");

        _platformFeeMultiplyer = multiplyer;
        _platformFeeDivider = divider;
    }

    function _getTotalNativeBalance() private view returns (uint256) {
        return address(this).balance.add(_totalBorrowNativeOrigin);
    }

    function _getTotalTokenBalance(DepositPair memory pair) private view returns (uint256) {
        return pair.originToken.balanceOf(address(this)).add(pair.originBorrowAmount);
    }
}

