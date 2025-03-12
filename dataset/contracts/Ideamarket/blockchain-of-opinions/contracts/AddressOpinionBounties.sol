//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IOpinionBounties.sol";
import "./utils/Ownable.sol";
import "./utils/Initializable.sol";
import "./interfaces/IAddressOpinionBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IArbSys.sol";

/**
 * @title AddressOpinionBounties
 * @author Kelton Madden
 *
 * @dev Allows for posting and claiming of bounties for opinions
 */

 contract AddressOpinionBounties is IOpinionBounties, Ownable, Initializable {

    // tokenAddress => whether it is an acceptable bounty payment
    mapping(address => bool) _isValidPayment;
    // address => user address => paymentTokenAddress => bounty info
    mapping(address => mapping(address => mapping(address => Bounty[]))) _bounties;

    // user address to Bounty[] of elibigle bounties for them
    address[] _payableTokens;

    bool feeSwitch;
    address _eth = 0x0000000000000000000000000000000000000000;
    IAddressOpinionBase _addressOpinionBase;
    IArbSys _arbSys = IArbSys(address(100));

    event BountyOffered(address addy, address user, address depositor, address token, uint amount);
    event BountyClaimed(address addy, address user, address token, uint amount);
    event BountyRescinded(address addy, address user, address depositor, address token, uint amount);
    //FIX INitalizaier
    
    constructor(address owner, address addressOpinionBase, address[] memory payableTokens) {
        setOwnerInternal(owner);
        _addressOpinionBase = IAddressOpinionBase(addressOpinionBase);
        for (uint i; i < payableTokens.length; i++) {
            _isValidPayment[payableTokens[i]] = true;
            _payableTokens.push(payableTokens[i]);
        }
    }

    function addBountiableToken(address token) external override {
        require(token != address(0), "zero-addr");
        require(!_isValidPayment[token], "token already added");
        _isValidPayment[token] = true;
        _payableTokens.push(token);
    }

    function removeBountiableToken(address token) external override {
        require(_isValidPayment[token], "token not added");
        _isValidPayment[token]= false;
        for (uint i = 0; i < _payableTokens.length; i++) {
            if (_payableTokens[i] == token) {
                _payableTokens[i] = _payableTokens[_payableTokens.length - 1];
                _payableTokens.pop();
            }
        }
    }

    function depositBounty(address addy, address user, address depositor, address token, uint amount) external override payable {
        require(amount > 0, "amount must be greater than 0");
        require(_isValidPayment[token], "invalid bounty payment");
        require(token != _eth || (token == _eth && msg.value == amount), "invalid ETH amount");
        uint blockHeight = _arbSys.arbBlockNumber();
        Bounty memory bounty = Bounty(amount, depositor, blockHeight);
        _bounties[addy][user][token].push(bounty);
        if (token != _eth) {
            require(IERC20(token).transferFrom(depositor, address(this), amount), "Transfer failed");
        }

        emit BountyOffered(addy, user, depositor, token, amount);
    }

    function rescindBounty(address addy, address user, address token) external override {
        uint amount;
        for (uint i = 0; i < _bounties[addy][user][token].length; i++) {
            if (_bounties[addy][user][token][i].depositor == msg.sender) {
                amount += _bounties[addy][user][token][i].amount;
                _bounties[addy][user][token][i] = _bounties[addy][user][token][_bounties[addy][user][token].length - 1];
                _bounties[addy][user][token].pop();
            }
        }
        if (addy == _eth) {
            (bool success, ) = msg.sender.call{value:amount}("");
            require(success, "Transfer failed.");
        } else {
            require(IERC20(token).transfer(msg.sender, amount), "Transfer failed.");
        }

        emit BountyRescinded(addy, user, msg.sender, token, amount);
    }

    function claimBounty(address addy, address token) external override {
        uint amount;
        IAddressOpinionBase.Opinion[] memory opinions = _addressOpinionBase.getOpinion(addy, msg.sender);
        Bounty[] memory bounties = _bounties[msg.sender][addy][token];
        delete bounties;

        for (uint i = 0; i < bounties.length; i++) {
            if (opinions[opinions.length - 1].blockHeight <= bounties[i].blockHeight) {
                amount += bounties[i].amount;
            } else {
                _bounties[addy][msg.sender][token].push(bounties[i]);
            }
        }
        if (addy == _eth) {
            (bool success, ) = msg.sender.call{value:amount}("");
            require(success, "Transfer failed.");
        } else {
            require(IERC20(token).transfer(msg.sender, amount), "Transfer failed.");
        }

        emit BountyClaimed(addy, msg.sender, token, amount);
    }

    function getAmountDepositedByUser(address addy, address user, address token) external view override returns (uint) {
        uint amount;
        for (uint i = 0; i < _bounties[user][addy][token].length; i++) {
            if (_bounties[user][addy][token][i].depositor == msg.sender) {
                amount += _bounties[user][addy][token][i].amount;
            }
        }
        return amount;
    }

    function getBountyAmountPayable(address addy, address user, address token) external view override returns (uint) {
        uint amount;
        IAddressOpinionBase.Opinion[] memory opinions = _addressOpinionBase.getOpinion(addy, msg.sender);
        for (uint i = 0; i <  _bounties[addy][msg.sender][token].length; i++) {
            if (opinions[opinions.length - 1].blockHeight <=  _bounties[addy][msg.sender][token][i].blockHeight) {
                amount +=  _bounties[addy][msg.sender][token][i].amount;
            }
        }
        return amount;
    }

    function setBountyFees(address token, uint8 fee) external override onlyOwner() {

    }

    function toggleFeeSwitch() external override onlyOwner() {
        feeSwitch = !feeSwitch;
    }

    function getBountyInfo(address addy, address user, address token) external view override returns (Bounty[] memory) {
        return _bounties[addy][user][token];
    }
 }