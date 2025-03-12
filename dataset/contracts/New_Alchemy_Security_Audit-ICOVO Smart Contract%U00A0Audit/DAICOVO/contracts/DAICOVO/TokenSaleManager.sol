pragma solidity ^0.4.18;

import "./TokenController.sol";
import "./TokenSale.sol";
import "../crowdsale/distribution/FinalizableCrowdsale.sol";
import "../crowdsale/validation/WhitelistedCrowdsale.sol";
import "./DaicoPool.sol";
import "../math/SafeMath.sol";


// @title 
/// @author ICOVO AG
/// @dev 
contract TokenSaleManager is Ownable {
    using SafeMath for uint256;

    ERC20Interface token;
    address public poolAddr;
    address public tokenControllerAddr;
    address public timeLockPoolAddr;
    address[] public tokenSales;
    mapping( address => bool ) public tokenSaleIndex;
    uint256 public baseRate;
    bool public isStarted = false;
    bool public isFinalized = false;

    modifier onlyDaicoPool {
        require(msg.sender == poolAddr);
        _;
    }

    modifier onlyTokenSale {
        require(tokenSaleIndex[msg.sender]);
        _;
    }

    function TokenSaleManager (
        address _tokenControllerAddr,
        address _timeLockPoolAddr,
        address _daicoPoolAddr,
        ERC20Interface _token
    ) public {
        require(_tokenControllerAddr != address(0x0));
        tokenControllerAddr = _tokenControllerAddr;

        require(_timeLockPoolAddr != address(0x0));
        timeLockPoolAddr = _timeLockPoolAddr;

        token = _token;

        poolAddr = _daicoPoolAddr;
        require(DaicoPool(poolAddr).votingTokenAddr() == address(token));
        DaicoPool(poolAddr).setTokenSaleContract(this);

    }

    function() external payable {
        revert();
    }

    function addTokenSale (
        uint256 openingTime,
        uint256 closingTime,
        uint256 tokensCap,
        uint256 rate,
        bool carryover,
        uint256 timeLockRate,
        uint256 timeLockEnd,
        uint256 minAcceptableWei
    ) external onlyOwner {
        require(!isStarted);
        require(
            tokenSales.length == 0 ||
            TimedCrowdsale(tokenSales[tokenSales.length-1]).closingTime() < openingTime
        );

        require(TokenController(tokenControllerAddr).state() == TokenController.State.Init);

        tokenSales.push(new TokenSale(
            rate,
            token,
            poolAddr,
            openingTime,
            closingTime,
            tokensCap,
            timeLockRate,
            timeLockEnd,
            carryover,
            minAcceptableWei
        ));
        tokenSaleIndex[tokenSales[tokenSales.length-1]] = true;

    }

    function initialize () external onlyOwner returns (bool) {
        require(!isStarted);
        TokenSale(tokenSales[0]).initialize(0);
        isStarted = true;
    }

    function mint (address _beneficiary, uint256 _tokenAmount) external onlyTokenSale returns(bool) {
        require(isStarted && !isFinalized);
        require(TokenController(tokenControllerAddr).mint(_beneficiary, _tokenAmount));
        return true;
    }

    function mintTimeLocked (
        address _beneficiary,
        uint256 _tokenAmount,
        uint256 _releaseTime
    ) external onlyTokenSale returns(bool) {
        require(isStarted && !isFinalized);
        require(TokenController(tokenControllerAddr).mint(this, _tokenAmount));
        require(ERC20Interface(token).approve(timeLockPoolAddr, _tokenAmount));
        require(TimeLockPool(timeLockPoolAddr).depositERC20(
            token,
            _beneficiary,
            _tokenAmount,
            _releaseTime
        ));
        return true;
    }

    function addToWhitelist(address _beneficiary) external onlyOwner {
        require(isStarted);
        for (uint256 i = 0; i < tokenSales.length; i++ ) {
            WhitelistedCrowdsale(tokenSales[i]).addToWhitelist(_beneficiary);
        }
    }

    function addManyToWhitelist(address[] _beneficiaries) external onlyOwner {
        require(isStarted);
        for (uint256 i = 0; i < tokenSales.length; i++ ) {
            WhitelistedCrowdsale(tokenSales[i]).addManyToWhitelist(_beneficiaries);
        }
    }


    function finalize (uint256 _indexTokenSale) external {
        require(isStarted && !isFinalized);
        TokenSale ts = TokenSale(tokenSales[_indexTokenSale]);

        if (ts.canFinalize()) {
            ts.finalize();
            uint256 carryoverAmount = 0;
            if (ts.carryover() &&
                ts.tokensCap() > ts.tokensMinted() &&
                _indexTokenSale.add(1) < tokenSales.length) {
                carryoverAmount = ts.tokensCap().sub(ts.tokensMinted());
            } 
            if(_indexTokenSale.add(1) < tokenSales.length) {
                TokenSale(tokenSales[_indexTokenSale.add(1)]).initialize(carryoverAmount);
            }
        }

    }

    function finalizeTokenSaleManager () external{
        require(isStarted && !isFinalized);
        for (uint256 i = 0; i < tokenSales.length; i++ ) {
            require(FinalizableCrowdsale(tokenSales[i]).isFinalized());
        }
        require(TokenController(tokenControllerAddr).closeTokensale());
        isFinalized = true;
        DaicoPool(poolAddr).startProject();
    }
}

