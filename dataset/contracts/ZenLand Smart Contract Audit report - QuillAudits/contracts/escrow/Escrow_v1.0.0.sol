// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import '../token/Token.sol';


contract Escrow_v100 {
    address public immutable buyer;
    address public immutable seller;
    address private immutable agent;
    uint256 public immutable contractPrice;
    uint256 public immutable buyerProtectionTime;
    Token public token;
    enum ContractStateChoices {
        DEPLOYED,
        FULFILLED,
        EXECUTED,
        DISPUTED,
        AGENT_INVITED,
        DISPUTE_FINISHED
    }
    ContractStateChoices public ContractState;
    uint256 public executionTimestamp;
    uint256 public immutable version;

    constructor(
        address _buyer,
        address _seller,
        address _agent,
        address _token,
        uint256 _contractPrice,
        uint256 _buyerProtectionTime
    ) {
        require(_buyer != _seller || _agent != _seller || _agent != _buyer, 'e001');
        require(msg.sender == _buyer, 'e003');
        require(_contractPrice > 0, 'e006');
        require(_buyerProtectionTime >= 60*60*24, 'e007');
        require(isContract(_token), 'e019');
        contractPrice = _contractPrice;
        buyer = _buyer;
        seller = _seller;
        agent = _agent;
        token = Token(_token);
        ContractState = ContractStateChoices.DEPLOYED;
        buyerProtectionTime = _buyerProtectionTime;
        version = 100;
    }

    function confirmFulfillment() external {
        require(msg.sender == seller, 'e004');
        require(ContractState == ContractStateChoices.DEPLOYED, 'e013');
        require(getBalanceOfContract() >= contractPrice, 'e002');
        ContractState = ContractStateChoices.FULFILLED;
        executionTimestamp = getCurrentTimestamp();
    }

    function release() external {
        require(msg.sender == buyer || msg.sender == seller, 'e012');
        require(
            ContractState == ContractStateChoices.DEPLOYED ||
            ContractState == ContractStateChoices.FULFILLED ||
            ContractState == ContractStateChoices.DISPUTED,
        'e017');
        require(getBalanceOfContract() >= contractPrice, 'e002');
        if (msg.sender == seller) {
            require(getCurrentTimestamp() > executionTimestamp + buyerProtectionTime, 'e009');
            require(ContractState == ContractStateChoices.FULFILLED, 'e014');
        }
        token.transfer(seller, contractPrice);
        ContractState = ContractStateChoices.EXECUTED;
    }

    function openDispute() external {
        require(msg.sender == buyer, 'e003');
        require(
            ContractState == ContractStateChoices.DEPLOYED ||
            ContractState == ContractStateChoices.FULFILLED,
        'e018');
        require(getBalanceOfContract() >= contractPrice, 'e002');
        ContractState = ContractStateChoices.DISPUTED;
    }

    function inviteAgent() external {
        require(msg.sender == buyer || msg.sender == seller, 'e012');
        require(ContractState == ContractStateChoices.DISPUTED, 'e015');
        ContractState = ContractStateChoices.AGENT_INVITED;
    }

    function sendMoney(uint256 _agentPercent, uint256 _buyerPercent, uint256 _sellerPercent) external {
        require(msg.sender == agent, 'e005');
        require(ContractState == ContractStateChoices.AGENT_INVITED, 'e016');
        require(_agentPercent >= 1 && _agentPercent <= 3, 'e010');
        require(_agentPercent + _buyerPercent + _sellerPercent == 100, 'e011');

        uint256 agentFee = _agentPercent * (getBalanceOfContract() - (getBalanceOfContract() - contractPrice)) / 100;
        uint256 buyerPart = _buyerPercent * (getBalanceOfContract() - (getBalanceOfContract() - contractPrice)) / 100;
        uint256 sellerPart = _sellerPercent * (getBalanceOfContract() - (getBalanceOfContract() - contractPrice)) / 100;
        token.transfer(agent, agentFee);
        token.transfer(buyer, buyerPart);
        token.transfer(seller, sellerPart);

        ContractState = ContractStateChoices.DISPUTE_FINISHED;
    }

    function returnMoney(address _token) external {
        require(msg.sender == buyer, 'e003');
        if (_token == address(token)) {
            if (token.balanceOf(address(this)) > contractPrice) {
                if (ContractState == ContractStateChoices.EXECUTED || ContractState == ContractStateChoices.DISPUTE_FINISHED) {
                    token.transfer(msg.sender, token.balanceOf(address(this)));
                } else {
                    token.transfer(msg.sender, token.balanceOf(address(this)) - contractPrice);
                }
            } else {
                revert('e008');
            }
        } else {
            Token wrongToken = Token(_token);
            if (wrongToken.balanceOf(address(this)) > 0) {
                wrongToken.transfer(msg.sender, wrongToken.balanceOf(address(this)));
            } else {
                revert('e008');
            }
        }
    }

    function balanceOf(address account) external view returns(uint256) {
        return token.balanceOf(account);
    }

    function getBalanceOfContract() public view returns(uint256) {
        return token.balanceOf(address(this));
    }

    function getCurrentTimestamp() public view returns(uint256) {
        return block.timestamp;
    }

    function isContract(address _address) public view returns(bool) {
        uint256 size;
        assembly { size := extcodesize(_address) }
        return size > 0;
    }
}
