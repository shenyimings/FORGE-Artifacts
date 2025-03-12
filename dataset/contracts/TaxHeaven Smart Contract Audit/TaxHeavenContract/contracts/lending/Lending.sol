// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "./LendingInterface.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../token/TaxTokenInterface.sol";
import "../util/TransferETH.sol";

contract Lending is LendingInterface, TransferETH {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    /* ========== CONSTANT VARIABLES ========== */

    address internal constant ETH_ADDRESS = address(0);
    uint256 internal constant COLLATERAL_RATIO = 100; // minimum collateral ratio is 100%.
    TaxTokenInterface internal immutable _taxTokenContract;
    address internal immutable _stakingAddress;
    uint256 internal immutable _interestE3; // 0.0% - 100.0%

    /* ========== STATE VARIABLES ========== */

    mapping(bytes32 => uint256) internal _lenderAccount; // keccak(tokenAddress, userAddress) => amount
    mapping(bytes32 => uint256) internal _borrowerAccount; // keccak(tokenAddress, userAddress) => amount
    mapping(bytes32 => uint256) internal _remainingCredit; // keccak(tokenAddress, userAddress) => amount
    mapping(address => uint256) internal _totalLending; // tokenAddress => amount
    mapping(address => uint256) internal _totalBorrowing; // tokenAddress => amount

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address taxTokenAddress,
        address stakingAddress,
        uint256 interestE3
    ) {
        _taxTokenContract = TaxTokenInterface(taxTokenAddress);
        _stakingAddress = stakingAddress;
        _interestE3 = interestE3;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice Deposit(lend) collateral in ETH.
     * As users can potentially be borrowers as well, the function charges the upfront interest fee.
     * Users can rececive the upfront interest fee in tax token.
     */
    function depositEth() external payable override {
        uint256 feeRate = _deposit(msg.sender, ETH_ADDRESS, msg.value);
        _transferETH(payable(_stakingAddress), feeRate);
    }

    /**
     * @notice Deposit(lend) collateral in any erc20 token.
     * As users can potentially be borrowers as well, the function charges the upfront interest fee.
     * Iff the erc20 token is whitelisted in the tax token, users can rececive the upfront interest fee in tax token.
     */
    function depositErc20(address tokenAddress, uint256 amount) external override {
        ERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        uint256 feeRate = _deposit(msg.sender, tokenAddress, amount);
        ERC20(tokenAddress).safeTransfer(_stakingAddress, feeRate);
    }

    /**
     * @notice Borrow up to the amount of remaining credit.
     */
    function borrow(address tokenAddress, uint256 amount) external override {
        _borrow(msg.sender, tokenAddress, amount);
        if (tokenAddress == ETH_ADDRESS) {
            _transferETH(msg.sender, amount);
        } else {
            ERC20(tokenAddress).safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice Withdraw the deposited (lended) collateral up to the amount of remaining credit.
     */
    function withdraw(address tokenAddress, uint256 amount) external override {
        _withdraw(msg.sender, tokenAddress, amount);
        if (tokenAddress == ETH_ADDRESS) {
            _transferETH(msg.sender, amount);
        } else {
            ERC20(tokenAddress).safeTransfer(msg.sender, amount);
        }
    }

    function repayEth() external payable override {
        _repay(msg.sender, ETH_ADDRESS, msg.value);
    }

    /**
     * @notice Repay the borrowing erc20 token up to the amount of borrowing.
     */
    function repayErc20(address tokenAddress, uint256 amount) external override {
        ERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        _repay(msg.sender, tokenAddress, amount);
    }

    /**
     * @notice Force liquidate if the user doesn't have enough collateral.
     */
    function forceLiquidate(address token, address userAddress) external override {
        bytes32 account = keccak256(abi.encode(token, userAddress));
        require(
            _borrowerAccount[account] > _lenderAccount[account].mul(COLLATERAL_RATIO.div(100)),
            "enough collateral"
        );
        _totalLending[token] -= _lenderAccount[account];
        _totalBorrowing[token] -= _borrowerAccount[account];
        _borrowerAccount[account] = 0;
        _lenderAccount[account] = 0;
        _remainingCredit[account] = 0;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _deposit(
        address lender,
        address tokenAddress,
        uint256 amount
    ) internal returns (uint256 feeRate) {
        require(amount != 0, "cannot deposit zero amount");
        feeRate = amount.mul(_interestE3).div(1000);
        _totalLending[tokenAddress] = _totalLending[tokenAddress].add(amount).sub(feeRate);
        bytes32 account = keccak256(abi.encode(tokenAddress, lender));
        _lenderAccount[account] = _lenderAccount[account].add(amount).sub(feeRate);
        _remainingCredit[account] = _remainingCredit[account].add(amount).sub(feeRate);
        _taxTokenContract.mintToken(tokenAddress, amount, lender);
    }

    function _borrow(
        address lender,
        address tokenAddress,
        uint256 amount
    ) internal {
        bytes32 account = keccak256(abi.encode(tokenAddress, lender));
        require(amount != 0, "should borrow positive amount");
        require(amount <= _remainingCredit[account], "too much borrow");
        _totalBorrowing[tokenAddress] = _totalBorrowing[tokenAddress].add(amount);
        _remainingCredit[account] = _remainingCredit[account].sub(amount);
        _borrowerAccount[account] = _borrowerAccount[account].add(amount);
    }

    function _withdraw(
        address lender,
        address tokenAddress,
        uint256 amount
    ) internal {
        bytes32 account = keccak256(abi.encode(tokenAddress, lender));
        require(amount != 0, "should withdraw positive amount");
        require(amount <= _remainingCredit[account], "too much withdraw");
        _totalLending[tokenAddress] = _totalLending[tokenAddress].sub(amount);
        _remainingCredit[account] = _remainingCredit[account].sub(amount);
        _lenderAccount[account] = _lenderAccount[account].sub(amount);
    }

    function _repay(
        address lender,
        address tokenAddress,
        uint256 amount
    ) internal {
        bytes32 account = keccak256(abi.encode(tokenAddress, lender));
        require(amount != 0, "should repay positive amount");
        require(amount <= _borrowerAccount[account], "too much repay");
        _totalBorrowing[tokenAddress] = _totalBorrowing[tokenAddress].sub(amount);
        _remainingCredit[account] = _remainingCredit[account].add(amount);
        _borrowerAccount[account] = _borrowerAccount[account].sub(amount);
    }

    /* ========== CALL FUNCTIONS ========== */

    /**
     * @return staking contract address
     */
    function getStakingAddress() external view override returns (address) {
        return _stakingAddress;
    }

    /**
     * @return tax token address
     */
    function getTaxTokenAddress() external view override returns (address) {
        return address(_taxTokenContract);
    }

    /**
     * @return interest fee charged when deposit
     */
    function getInterest() external view override returns (uint256) {
        return _interestE3;
    }

    /**
     * @return total value locked of the token
     */
    function getTvl(address tokenAddress) external view override returns (uint256) {
        return _totalLending[tokenAddress];
    }

    /**
     * @return total lending amount of the token
     */
    function getTotalLending(address tokenAddress) external view override returns (uint256) {
        return _totalLending[tokenAddress];
    }

    /**
     * @return total borrowing amount of the token
     */
    function getTotalBorrowing(address tokenAddress) external view override returns (uint256) {
        return _totalBorrowing[tokenAddress];
    }

    /**
     * @notice Get token info
     */
    function getTokenInfo(address tokenAddress)
        external
        view
        override
        returns (uint256 totalLendAmount, uint256 totalBorrowAmount)
    {
        totalLendAmount = _totalLending[tokenAddress];
        totalBorrowAmount = _totalBorrowing[tokenAddress];
    }

    /**
     * @return total lending amount of the token belonging to the user
     */
    function getLenderAccount(address tokenAddress, address userAddress)
        external
        view
        override
        returns (uint256)
    {
        bytes32 account = keccak256(abi.encode(tokenAddress, userAddress));
        return _lenderAccount[account];
    }

    /**
     * @return total borrowing amount of the token belonging to the user
     */
    function getBorrowerAccount(address tokenAddress, address userAddress)
        external
        view
        override
        returns (uint256)
    {
        bytes32 account = keccak256(abi.encode(tokenAddress, userAddress));
        return _borrowerAccount[account];
    }

    /**
     * @return remaining credit amount of the token belonging to the user
     */
    function getRemainingCredit(address tokenAddress, address userAddress)
        external
        view
        override
        returns (uint256)
    {
        bytes32 account = keccak256(abi.encode(tokenAddress, userAddress));
        return _remainingCredit[account];
    }

    /**
     * @notice Get account info of the token belonging to the user
     */
    function getAccountInfo(address tokenAddress, address userAddress)
        external
        view
        override
        returns (
            uint256 lendAccount,
            uint256 borrowAccount,
            uint256 remainingCredit
        )
    {
        bytes32 account = keccak256(abi.encode(tokenAddress, userAddress));
        lendAccount = _lenderAccount[account];
        borrowAccount = _borrowerAccount[account];
        remainingCredit = _remainingCredit[account];
    }
}
