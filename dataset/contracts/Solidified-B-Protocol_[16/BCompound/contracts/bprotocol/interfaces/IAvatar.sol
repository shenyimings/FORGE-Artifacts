pragma solidity 0.5.16;

contract IERC20 {
    function transfer(address cToken, address dst, uint256 amount) external returns (bool);
    function transferFrom(address cToken, address src, address dst, uint256 amount) external returns (bool);
    function approve(address cToken, address spender, uint256 amount) public returns (bool);
}

contract IAvatar is IERC20 {
    function initialize(address _registry, address comp, address compVoter) external;
    function quit() external returns (bool);
    function canUntop() public returns (bool);
    function toppedUpCToken() external returns (address);
    function toppedUpAmount() external returns (uint256);
    function redeem(address cToken, uint256 redeemTokens, address payable userOrDelegatee) external returns (uint256);
    function redeemUnderlying(address cToken, uint256 redeemAmount, address payable userOrDelegatee) external returns (uint256);
    function borrow(address cToken, uint256 borrowAmount, address payable userOrDelegatee) external returns (uint256);
    function borrowBalanceCurrent(address cToken) external returns (uint256);
    function collectCToken(address cToken, address from, uint256 cTokenAmt) public;
    function liquidateBorrow(uint repayAmount, address cTokenCollateral) external payable returns (uint256);

    // Comptroller functions
    function enterMarket(address cToken) external returns (uint256);
    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);
    function exitMarket(address cToken) external returns (uint256);
    function claimComp() external;
    function claimComp(address[] calldata bTokens) external;
    function claimComp(address[] calldata bTokens, bool borrowers, bool suppliers) external;
    function getAccountLiquidity() external view returns (uint err, uint liquidity, uint shortFall);
}

// Workaround for issue https://github.com/ethereum/solidity/issues/526
// CEther
contract IAvatarCEther is IAvatar {
    function mint() external payable;
    function repayBorrow() external payable;
    function repayBorrowBehalf(address borrower) external payable;
}

// CErc20
contract IAvatarCErc20 is IAvatar {
    function mint(address cToken, uint256 mintAmount) external returns (uint256);
    function repayBorrow(address cToken, uint256 repayAmount) external returns (uint256);
    function repayBorrowBehalf(address cToken, address borrower, uint256 repayAmount) external returns (uint256);
}

contract ICushion {
    function liquidateBorrow(uint256 underlyingAmtToLiquidate, uint256 amtToDeductFromTopup, address cTokenCollateral) external payable returns (uint256);    
    function canLiquidate() external returns (bool);
    function untop(uint amount) external;
    function toppedUpAmount() external returns (uint);
    function remainingLiquidationAmount() external returns(uint);
    function getMaxLiquidationAmount(address debtCToken) public returns (uint256);
}

contract ICushionCErc20 is ICushion {
    function topup(address cToken, uint256 topupAmount) external;
}

contract ICushionCEther is ICushion {
    function topup() external payable;
}