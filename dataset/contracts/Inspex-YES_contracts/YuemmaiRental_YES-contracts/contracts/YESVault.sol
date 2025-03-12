//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IYESVault.sol";
import "./interfaces/IYESController.sol";
import "./interfaces/IYESToken.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IMarketImpl.sol";
import "./libraries/math/Exponential.sol";
import "./libraries/parser/Parser.sol";
import "./modules/kap20/interfaces/IKAP20.sol";
import "./modules/timelock/Timelock.sol";
import "./modules/admin/Authorization.sol";
import "./modules/security//ReentrancyGuard.sol";
import "./modules/kyc/KYCHandler.sol";

contract YESVault is IYESVault, Timelock, Authorization, KYCHandler {
    IYESController private _controller;
    IYESToken private _yesToken;

    address private _marketImpl;
    address private _market;

    mapping(address => uint256) private _airdropOf;
    mapping(address => uint256) private _depositOf;
    mapping(address => uint256) private _releasedTo;

    uint256 private _slippageTolerrance = 0.005e18; //0.5%
    uint256 private _totalAllocated;

    constructor(
        address controller_,
        address yesToken_,
        address marketImpl_,
        address market_,
        uint256 releaseTime_,
        address adminRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    )
        Timelock(releaseTime_)
        Authorization(adminRouter_)
        KYCHandler(kyc_, acceptedKycLevel_)
    {
        _setController(controller_);
        _setYESToken(yesToken_);
        _setMarketImpl(marketImpl_);
        _setMarket(market_);
    }

    receive() external payable {}

    function airdrop(address beneficiary, uint256 amount)
        external
        override
        onlyAdmin
    {
        _airdropOf[beneficiary] += amount;
        _releasedTo[beneficiary] += amount;
        _totalAllocated += amount;
        require(
            _totalAllocated <= _yesToken.balanceOf(address(this)),
            "Airdrop exceed supply"
        );
        emit Airdrop(beneficiary, amount);
    }

    function deposit(uint256 amount) external override {
        _yesToken.transferFrom(msg.sender, address(this), amount);
        _deposit(amount, msg.sender);
    }

    function depositBKNext(uint256 amount, address _bitkubnext)
        external
        override
        onlySuperAdmin
    {
        require(
            kyc.kycsLevel(_bitkubnext) >= acceptedKycLevel,
            "only Bitkub Next user"
        );
        _yesToken.externalTransfer(_bitkubnext, address(this), amount);
        _deposit(amount, _bitkubnext);
    }

    function _deposit(uint256 amount, address sender) private {
        _depositOf[sender] += amount;
        _totalAllocated += amount;
        emit Deposit(sender, amount);
    }

    function withdraw(uint256 amount) external override onlyUnlocked {
        _withdraw(amount, msg.sender);
    }

    function withdrawBKNext(uint256 amount, address _bitkubnext)
        external
        override
        onlyUnlocked
        onlySuperAdmin
    {
        require(
            kyc.kycsLevel(_bitkubnext) >= acceptedKycLevel,
            "only Bitkub Next user"
        );
        _withdraw(amount, _bitkubnext);
    }

    function _withdraw(uint256 amount, address sender) private {
        (, , , uint256 borrowValue) = _controller.getAccountLiquidity(sender);
        uint256 senderTokens = tokensOf(sender);

        require(senderTokens >= borrowValue, "YESVault: ACCOUNT_SHORT_FALL");
        require(
            senderTokens - borrowValue >= amount,
            "YESVault: NOT_ENOUGH_BALANCE"
        );

        uint256 senderAirdrop = _airdropOf[sender];

        if (amount <= _airdropOf[sender]) {
            _airdropOf[sender] -= amount;
        } else {
            _airdropOf[sender] = 0;
            _depositOf[sender] -= (amount - senderAirdrop);
        }

        _totalAllocated -= amount;

        _yesToken.transfer(sender, amount);

        emit Withdraw(sender, amount);
    }

    function sellMarket(address borrower, uint256 sellAmount)
        external
        payable
        override
        returns (uint256)
    {
        uint256 err = _controller.seizeAllowed(msg.sender);
        require(err == 0, "YESVault: LIQUIDATE_SEIZE_CONTROLLER_REJECTION");

        address token = ILending(msg.sender).underlyingToken();

        uint256 borrowerTokens = tokensOf(borrower);
        uint256 borrowerDeposit = _depositOf[borrower];

        // If the borrower has lower tokens than sellAmount, sell all of his/her tokens
        uint256 amountIn = sellAmount < borrowerTokens
            ? sellAmount
            : borrowerTokens;

        (bool success, bytes memory data) = _marketImpl.delegatecall(
            abi.encodeWithSignature(
                "merketSell(address,address,address,uint256,address,uint256)",
                _market,
                yesToken(),
                token,
                amountIn,
                payable(this),
                _slippageTolerrance
            )
        );

        require(success, "YESVault: DELEGATECALL FAILED");

        uint256 amountOut = Parser.toUint256(data);

        // If there borrower's tokens were not bought all
        if (amountIn == sellAmount) {
            // Seize all of his/her airdrop
            uint256 yesSeized = sellAmount < borrowerDeposit
                ? _airdropOf[borrower]
                : (borrowerTokens - sellAmount);
            _totalAllocated -= yesSeized;
        }

        _depositOf[borrower] = sellAmount < borrowerDeposit
            ? (borrowerDeposit - sellAmount)
            : 0;
        _airdropOf[borrower] = 0;
        _totalAllocated -= amountIn;

        if (token == address(0)) {
            payable(msg.sender).transfer(amountOut);
        } else {
            IKAP20(token).transfer(msg.sender, amountOut);
        }

        return amountOut;
    }

    /*** Admin Functions ***/
    function _setController(address newController)
        public
        override
        onlyAdmin
    {
        IYESController oldController = _controller;
        _controller = IYESController(newController);
        require(_controller.isController(), "YESVault: INVALID_CONTROLLER");
        emit NewController(address(oldController), newController);
    }

    function _setYESToken(address newYESToken) public override onlyAdmin {
        IYESToken oldYESToken = _yesToken;
        _yesToken = IYESToken(newYESToken);
        emit NewYESToken(address(oldYESToken), newYESToken);
    }

    function _setMarketImpl(address newImpl) public override onlyAdmin {
        address oldImpl = _marketImpl;
        _marketImpl = newImpl;
        emit NewMarketImpl(oldImpl, newImpl);
    }

    function _setMarket(address newMarket) public override onlyAdmin {
        address oldMarket = _market;
        _market = newMarket;
        emit NewMarket(oldMarket, newMarket);
    }

    function _setSlippageTolerrance(uint256 newTolerrance)
        public
        override
        onlyAdmin
    {
        uint256 oldTolerrance = _slippageTolerrance;
        _slippageTolerrance = newTolerrance;
        emit NewSlippageTolerrance(oldTolerrance, newTolerrance);
    }

    function activateOnlyKycAddress() public override onlyAdmin {
        _activateOnlyKycAddress();
    }

    function setKYC(address _kyc) public override onlyAdmin {
        _setKYC(IKYCBitkubChain(_kyc));
    }

    function setAcceptedKycLevel(uint256 _kycLevel) public override onlyAdmin {
        _setAcceptedKycLevel(_kycLevel);
    }

    /*** Getters ***/

    function tokensOf(address account) public view override returns (uint256) {
        return _airdropOf[account] + _depositOf[account];
    }

    function depositOf(address account) public view override returns (uint256) {
        return _depositOf[account];
    }

    function airdropOf(address account) public view override returns (uint256) {
        return _airdropOf[account];
    }

    function releasedTo(address account)
        public
        view
        override
        returns (uint256)
    {
        return _releasedTo[account];
    }

    function controller() public view override returns (address) {
        return address(_controller);
    }

    function yesToken() public view override returns (address) {
        return address(_yesToken);
    }

    function marketImpl() public view override returns (address) {
        return _marketImpl;
    }

    function market() public view override returns (address) {
        return _market;
    }

    function slippageTolerrance() public view override returns (uint256) {
        return _slippageTolerrance;
    }

    function totalAllocated() public view override returns (uint256) {
        return _totalAllocated;
    }
}
