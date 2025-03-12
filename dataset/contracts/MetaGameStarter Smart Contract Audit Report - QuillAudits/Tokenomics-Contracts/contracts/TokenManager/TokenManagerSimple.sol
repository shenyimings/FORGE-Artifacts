pragma solidity ^0.8.0.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ITokenController {
    function proxyPayment(address _owner) external payable returns(bool);
    function onTransfer(address _from, address _to, uint _amount) external returns(bool);
    function onApprove(address _owner, address _spender, uint _amount) external returns(bool);
}

interface Token {
    function generateTokens(address _owner, uint _amount) external returns (bool);
    function destroyTokens(address _owner, uint _amount) external returns (bool);
    function claimTokens(address _token) external;
}

contract TokenManagerSimple is Ownable, ITokenController {
    Token constant public token = Token(0x8765b1A0eb57ca49bE7EACD35b24A574D0203656);

    constructor() {
        _transferOwnership(0x2a9Da28bCbF97A8C008Fd211f5127b860613922D);
    }

    function burn(uint256 amount) external {
        require(token.destroyTokens(msg.sender, amount));
    }

    function burnFrom(address from, uint256 amount) external onlyOwner {
        require(token.destroyTokens(from, amount));
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(token.generateTokens(to, amount));
    }

    function rescue(address __token) external onlyOwner {
        token.claimTokens(__token);
    }

    function proxyPayment(address _owner) external payable override returns(bool) {
        revert("not implemented");
    }
    function onTransfer(address _from, address _to, uint _amount) external override returns(bool) {
        return true;
    }
    function onApprove(address _owner, address _spender, uint _amount) external override returns(bool) {
        return true;
    }

    function anything(address callee, bytes calldata data) external payable onlyOwner {
        (bool succ,) = callee.call{ value: msg.value }(data);
        require(succ);
    }
}