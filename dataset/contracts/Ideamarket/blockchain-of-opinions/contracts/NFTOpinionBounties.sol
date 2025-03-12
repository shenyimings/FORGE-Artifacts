//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/INFTOpinionBounties.sol";
import "./utils/Ownable.sol";
import "./utils/Initializable.sol";
import "./interfaces/INFTOpinionBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IArbSys.sol";
//fix
import "hardhat/console.sol";
/**
 * @title NFTOpinionBounties
 * @author Kelton Madden
 *
 * @dev Allows for posting and claiming of bounties for opinions
 */

 contract NFTOpinionBounties is INFTOpinionBounties, Ownable, Initializable {

    // tokenAddress => whether it is an acceptable bounty payment
    mapping(address => bool) _isValidPayment;
    // address => user address => paymentTokenAddress => bounty info
    mapping(uint => mapping(address => mapping(address => Bounty[]))) _bounties;
    // address => claimable owner fees
    mapping(address => uint) _ownerFees;
    //fee percentage for bounties of a particular token
    //fee format is a uint with 2 digits representing a percentage (ex: 2.5% => 025)
    mapping(address => uint8) _tokenFeePercentage; 

    // user address to Bounty[] of elibigle bounties for them
    address[] _payableTokens;
    bool public _feeSwitch;

    address _eth;
    INFTOpinionBase _nftOpinionBase;
    IArbSys _arbSys;

    event BountyOffered(uint tokenID, address user, address depositor, address token, uint amount, uint fee);
    event BountyClaimed(uint tokenID, address user, address token, uint amount);
    event BountyRescinded(uint tokenID, address user, address depositor, address token, uint amount);

    function initialize(address owner, address nftOpinionBase, address[] memory payableTokens, uint8[] memory tokenFeePercentage, bool feeSwitch) external initializer{
        require(owner!= address(0), "zero-addr");
        require(payableTokens.length == tokenFeePercentage.length, "arr-length-mismatch");

        setOwnerInternal(owner);
        _feeSwitch = feeSwitch;
        _nftOpinionBase = INFTOpinionBase(nftOpinionBase);
        _arbSys = IArbSys(address(100));
        _eth = address(0x0000000000000000000000000000000000000000);
        for (uint i; i < payableTokens.length; i++) {
            _isValidPayment[payableTokens[i]] = true;
            _payableTokens.push(payableTokens[i]);
            _tokenFeePercentage[payableTokens[i]] = tokenFeePercentage[i];
        }
    }

    function depositBounty(uint tokenID, address user, address depositor, address token, uint amount) external override payable {
        require(amount > 0, "amount must be greater than 0");
        require(_isValidPayment[token], "invalid bounty payment");
        require(token != _eth || (token == _eth && msg.value == amount), "invalid ETH amount");
        //fix
        //uint blockHeight = _arbSys.arbBlockNumber();
        uint blockHeight = block.number;
        uint fee = 0;
        uint modifiedAmount = amount;
        if (_feeSwitch) {
            fee = amount *_tokenFeePercentage[token]  / 1000;
            modifiedAmount = amount - fee;
        }
        Bounty memory bounty = Bounty(modifiedAmount, depositor, blockHeight);
        _bounties[tokenID][user][token].push(bounty);
        if (token != _eth) {
            require(IERC20(token).transferFrom(depositor, address(this), amount), "Transfer failed");
        }
        _ownerFees[token] += fee;
        emit BountyOffered(tokenID, user, depositor, token, modifiedAmount, fee);
    }

    function rescindBounty(uint tokenID, address user, address token, uint withdrawAmount) external override {
        uint amount;
        for (uint i = 0; i < _bounties[tokenID][user][token].length; i++) {
            if (_bounties[tokenID][user][token][i].depositor == msg.sender) {
                amount += _bounties[tokenID][user][token][i].amount;
                _bounties[tokenID][user][token][i] = _bounties[tokenID][user][token][_bounties[tokenID][user][token].length - 1];
                _bounties[tokenID][user][token].pop();
            }
        }
        if (amount > withdrawAmount) {
            //fix
            //uint blockHeight = _arbSys.arbBlockNumber();
            uint blockHeight = block.number;
            Bounty memory bounty = Bounty(amount - withdrawAmount, msg.sender, blockHeight);
            _bounties[tokenID][user][token].push(bounty);
        } else {
            withdrawAmount = amount;
        }
        if (token == _eth) {
            (bool success, ) = msg.sender.call{value: withdrawAmount}("");
            require(success, "Transfer failed.");
        } else {
            require(IERC20(token).transfer(msg.sender, withdrawAmount), "Transfer failed.");
        }

        emit BountyRescinded(tokenID, user, msg.sender, token, withdrawAmount);
    }

    function claimBounty(uint tokenID, address token) external override {
        uint amount;
        INFTOpinionBase.Opinion[] memory opinions = _nftOpinionBase.getOpinion(tokenID, msg.sender);
        if (opinions.length == 0) {
            return;
        } 
        Bounty[] memory bounties = _bounties[tokenID][msg.sender][token];
        delete _bounties[tokenID][msg.sender][token];
    //fix must have commented
        for (uint i = 0; i < bounties.length; i++) {
            if (opinions[opinions.length - 1].blockHeight >= bounties[i].blockHeight) {
                amount += bounties[i].amount;
            } else {
                _bounties[tokenID][msg.sender][token].push(bounties[i]);
            }
        }
        if (token == _eth) {
            (bool success, ) = msg.sender.call{value:amount}("");
            require(success, "Transfer failed.");
        } else {
            require(IERC20(token).transfer(msg.sender, amount), "Transfer failed.");
        }

        emit BountyClaimed(tokenID, msg.sender, token, amount);
    }

    function addBountiableToken(address token) external override onlyOwner() {
        require(!_isValidPayment[token], "token-already-added");
        _isValidPayment[token] = true;
        _payableTokens.push(token);
    }

    function removeBountiableToken(address token) external override onlyOwner() {
        require(_isValidPayment[token], "token-not-added");
        _isValidPayment[token]= false;
        for (uint i = 0; i < _payableTokens.length; i++) {
            if (_payableTokens[i] == token) {
                _payableTokens[i] = _payableTokens[_payableTokens.length - 1];
                _payableTokens.pop();
            }
        }
    }

    function setBountyFees(address token, uint8 fee) external override onlyOwner() {
        require(_isValidPayment[token], "invalid-token");
        _tokenFeePercentage[token] = fee;
    }

    function withdrawOwnerFees() external override onlyOwner() {
        for (uint i; i < _payableTokens.length; i++) {
            if (_payableTokens[i] != _eth) {
                uint amount = _ownerFees[_payableTokens[i]];
                _ownerFees[_payableTokens[i]] = 0;
                require(IERC20(_payableTokens[i]).transfer(_owner, amount), "Transfer failed");

            } else {
                uint amount = _ownerFees[_payableTokens[i]];
                _ownerFees[_payableTokens[i]] = 0;
                (bool sent,) = _owner.call{value:amount}("");
                require(sent, "Transfer failed");
            }
        }
    }

    function getAmountDepositedByUser(uint tokenID, address user, address depositor, address token) external view override returns (uint) {
        uint amount;
        for (uint i = 0; i < _bounties[tokenID][user][token].length; i++) {
            if (_bounties[tokenID][user][token][i].depositor == depositor) {
                amount += _bounties[tokenID][user][token][i].amount;
            }
        }
        return amount;
    }

    function getBountyAmountPayable(uint tokenID, address user, address token) external view override returns (uint) {
        uint amount;
        INFTOpinionBase.Opinion[] memory opinions = _nftOpinionBase.getOpinion(tokenID, user);
        if (opinions.length == 0) {
            return 0;
        }     //fix must have commented
        for (uint i = 0; i <  _bounties[tokenID][user][token].length; i++) {
            if (opinions[opinions.length - 1].blockHeight >=  _bounties[tokenID][user][token][i].blockHeight) {
                amount +=  _bounties[tokenID][user][token][i].amount;
            }
        }
        return amount;
    }

    function getOwnerFeesPayable(address token) external view override returns (uint) {
        return _ownerFees[token];
    }

    function getBountyInfo(uint tokenID, address user, address token) external view override returns (Bounty[] memory) {
        return _bounties[tokenID][user][token];
    }

    function toggleFeeSwitch() external override onlyOwner() {
        _feeSwitch = !_feeSwitch;
    }
 }