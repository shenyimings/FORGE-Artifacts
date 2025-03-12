pragma solidity 0.7.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../../interfaces/ICToken.sol";
import "../../../interfaces/IComptroller.sol";
import "../../../interfaces/IOwnable.sol";
import "../../../interfaces/ILegacyERC20.sol";
import "../MediatorOwnableModule.sol";
import "./BaseInterestERC20.sol";

/**
 * @title CompoundInterestERC20
 * @dev This contract contains token-specific logic for investing ERC20 tokens into Compound protocol.
 */
contract CompoundInterestERC20 is BaseInterestERC20, MediatorOwnableModule {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ICToken;

    uint256 internal constant SUCCESS = 0;

    struct InterestParams {
        ICToken cToken;
        uint96 dust;
        uint256 investedAmount;
        address interestReceiver;
        uint256 minInterestPaid;
    }

    mapping(address => InterestParams) public interestParams;
    uint256 public minCompPaid;
    address public compReceiver;

    constructor(
        address _omnibridge,
        address _owner,
        uint256 _minCompPaid,
        address _compReceiver
    ) MediatorOwnableModule(_omnibridge, _owner) {
        minCompPaid = _minCompPaid;
        compReceiver = _compReceiver;
    }

    /**
     * @dev Tells the module interface version that this contract supports.
     * @return major value of the version
     * @return minor value of the version
     * @return patch value of the version
     */
    function getModuleInterfacesVersion()
        external
        pure
        returns (
            uint64 major,
            uint64 minor,
            uint64 patch
        )
    {
        return (1, 0, 0);
    }

    /**
     * @dev Enables support for interest earning through specific cToken.
     * @param _cToken address of the cToken contract. Underlying token address is derived from this contract.
     * @param _dust small amount of underlying tokens that cannot be paid as an interest. Accounts for possible truncation errors.
     * @param _interestReceiver address of the interest receiver for underlying token.
     * @param _minInterestPaid min amount of underlying tokens to be paid as an interest.
     */
    function enableInterestToken(
        ICToken _cToken,
        uint96 _dust,
        address _interestReceiver,
        uint256 _minInterestPaid
    ) external onlyOwner {
        address token = _cToken.underlying();
        // disallow reinitialization of tokens that were already initialized and invested
        require(interestParams[token].investedAmount == 0);

        interestParams[token] = InterestParams(_cToken, _dust, 0, _interestReceiver, _minInterestPaid);

        // SafeERC20.safeApprove does not work here in case of possible interest reinitialization,
        // since it does not allow positive->positive allowance change. However, it would be safe to make such change here.
        ILegacyERC20(token).approve(address(_cToken), uint256(-1));

        emit InterestEnabled(token, address(_cToken));
        emit InterestDustUpdated(token, _dust);
        emit InterestReceiverUpdated(token, _interestReceiver);
        emit MinInterestPaidUpdated(token, _minInterestPaid);
    }

    /**
     * @dev Tells the current amount of underlying tokens that was invested into the Compound protocol.
     * @param _token address of the underlying token.
     * @return currently invested value.
     */
    function investedAmount(address _token) external view override returns (uint256) {
        return interestParams[_token].investedAmount;
    }

    /**
     * @dev Tells the address of the COMP token in the Ethereum Mainnet.
     */
    function compToken() public pure virtual returns (IERC20) {
        return IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    }

    /**
     * @dev Tells the address of the Comptroller contract in the Ethereum Mainnet.
     */
    function comptroller() public pure virtual returns (IComptroller) {
        return IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    }

    /**
     * @dev Tells if interest earning is supported for the specific underlying token contract.
     * @param _token address of the token contract.
     * @return true, if interest earning is supported for the given token.
     */
    function isInterestSupported(address _token) external view override returns (bool) {
        return address(interestParams[_token].cToken) != address(0);
    }

    /**
     * @dev Invests the given amount of tokens to the Compound protocol.
     * Only Omnibridge contract is allowed to call this method.
     * Converts _amount of TOKENs into X cTOKENs.
     * @param _token address of the invested token contract.
     * @param _amount amount of tokens to invest.
     */
    function invest(address _token, uint256 _amount) external override onlyMediator {
        InterestParams storage params = interestParams[_token];
        params.investedAmount = params.investedAmount.add(_amount);
        require(params.cToken.mint(_amount) == SUCCESS);
    }

    /**
     * @dev Withdraws at least min(_amount, investedAmount) of tokens from the Compound protocol.
     * Only Omnibridge contract is allowed to call this method.
     * Converts X cTOKENs into _amount of TOKENs.
     * @param _token address of the invested token contract.
     * @param _amount minimal amount of tokens to withdraw.
     */
    function withdraw(address _token, uint256 _amount) external override onlyMediator {
        InterestParams storage params = interestParams[_token];
        uint256 invested = params.investedAmount;
        uint256 redeemed = _safeWithdraw(_token, _amount > invested ? invested : _amount);
        params.investedAmount = redeemed > invested ? 0 : invested - redeemed;
        IERC20(_token).safeTransfer(mediator, redeemed);
    }

    /**
     * @dev Tells the current accumulated interest on the invested tokens, that can be withdrawn and payed to the interest receiver.
     * @param _token address of the invested token contract.
     * @return amount of accumulated interest.
     */
    function interestAmount(address _token) public returns (uint256) {
        InterestParams storage params = interestParams[_token];
        (ICToken cToken, uint96 dust) = (params.cToken, params.dust);
        uint256 balance = cToken.balanceOfUnderlying(address(this));
        // small portion of tokens are reserved for possible truncation/round errors
        uint256 reserved = params.investedAmount.add(dust);
        return balance > reserved ? balance - reserved : 0;
    }

    /**
     * @dev Pays collected interest for the underlying token.
     * Anyone can call this function.
     * Earned interest is withdrawn and transferred to the specified interest receiver account.
     * @param _token address of the invested token contract in which interest should be paid.
     */
    function payInterest(address _token) external onlyEOA {
        InterestParams storage params = interestParams[_token];
        uint256 interest = interestAmount(_token);
        require(interest >= params.minInterestPaid);
        _transferInterest(params.interestReceiver, address(_token), _safeWithdraw(_token, interest));
    }

    /**
     * @dev Tells the amount of earned COMP tokens for supplying assets into the protocol that can be withdrawn.
     * Intended to be called via eth_call to obtain the current accumulated value for COMP.
     * @return amount of accumulated COMP tokens across given markets.
     */
    function compAmount(address[] calldata _markets) public returns (uint256) {
        address[] memory holders = new address[](1);
        holders[0] = address(this);
        comptroller().claimComp(holders, _markets, false, true);

        return compToken().balanceOf(address(this));
    }

    /**
     * @dev Claims Comp token received by supplying underlying tokens and transfers it to the associated COMP receiver.
     * @param _markets cTokens addresses to claim COMP for.
     */
    function claimCompAndPay(address[] calldata _markets) external onlyEOA {
        uint256 balance = compAmount(_markets);
        require(balance >= minCompPaid);
        _transferInterest(compReceiver, address(compToken()), balance);
    }

    /**
     * @dev Last-resort function for returning assets to the Omnibridge contract in case of some failures in the logic.
     * Disables this contract and transfers locked tokens back to the mediator.
     * Only owner is allowed to call this method.
     * @param _token address of the invested token contract that should be disabled.
     */
    function forceDisable(address _token) external onlyOwner {
        InterestParams storage params = interestParams[_token];
        ICToken cToken = params.cToken;

        uint256 cTokenBalance = cToken.balanceOf(address(this));
        // try to redeem all cTokens
        if (cToken.redeem(cTokenBalance) == SUCCESS) {
            cTokenBalance = 0;
        } else {
            // transfer cTokens as-is, if redeem has failed
            cToken.safeTransfer(mediator, cTokenBalance);
        }

        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(mediator, balance);
        IERC20(_token).safeApprove(address(cToken), 0);

        emit ForceDisable(_token, balance, cTokenBalance, params.investedAmount);

        delete interestParams[_token];
    }

    /**
     * @dev Updates dust parameter for the particular token.
     * Only owner is allowed to call this method.
     * @param _token address of the invested token contract.
     * @param _dust new amount of underlying tokens that cannot be paid as an interest. Accounts for possible truncation errors.
     */
    function setDust(address _token, uint96 _dust) external onlyOwner {
        interestParams[_token].dust = _dust;
        emit InterestDustUpdated(_token, _dust);
    }

    /**
     * @dev Updates address of the interest receiver. Can be any address, EOA or contract.
     * Set to 0x00..00 to disable interest transfers.
     * Only owner is allowed to call this method.
     * @param _token address of the invested token contract.
     * @param _receiver address of the interest receiver.
     */
    function setInterestReceiver(address _token, address _receiver) external onlyOwner {
        interestParams[_token].interestReceiver = _receiver;
        emit InterestReceiverUpdated(_token, _receiver);
    }

    /**
     * @dev Updates min interest amount that can be transferred in single call.
     * Only owner is allowed to call this method.
     * @param _token address of the invested token contract.
     * @param _minInterestPaid new amount of TOKENS and can be transferred to the interest receiver in single operation.
     */
    function setMinInterestPaid(address _token, uint256 _minInterestPaid) external onlyOwner {
        interestParams[_token].minInterestPaid = _minInterestPaid;
        emit MinInterestPaidUpdated(_token, _minInterestPaid);
    }

    /**
     * @dev Updates min COMP amount that can be transferred in single call.
     * Only owner is allowed to call this method.
     * @param _minCompPaid new amount of COMP and can be transferred to the interest receiver in single operation.
     */
    function setMinCompPaid(uint256 _minCompPaid) external onlyOwner {
        minCompPaid = _minCompPaid;
        emit MinInterestPaidUpdated(address(compToken()), _minCompPaid);
    }

    /**
     * @dev Updates address of the accumulated COMP receiver. Can be any address, EOA or contract.
     * Set to 0x00..00 to disable COMP claims and transfers.
     * Only owner is allowed to call this method.
     * @param _receiver address of the interest receiver.
     */
    function setCompReceiver(address _receiver) external onlyOwner {
        compReceiver = _receiver;
        emit InterestReceiverUpdated(address(compToken()), _receiver);
    }

    /**
     * @dev Internal function for securely withdrawing assets from the underlying protocol.
     * @param _token address of the invested token contract.
     * @param _amount minimal amount of underlying tokens to withdraw from Compound.
     * @return amount of redeemed tokens, at least as much as was requested.
     */
    function _safeWithdraw(address _token, uint256 _amount) private returns (uint256) {
        uint256 balance = IERC20(_token).balanceOf(address(this));

        require(interestParams[_token].cToken.redeemUnderlying(_amount) == SUCCESS);

        uint256 redeemed = IERC20(_token).balanceOf(address(this)) - balance;

        require(redeemed >= _amount);

        return redeemed;
    }
}
