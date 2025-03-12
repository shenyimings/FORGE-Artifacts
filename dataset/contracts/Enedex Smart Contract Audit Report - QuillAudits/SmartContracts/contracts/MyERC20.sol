// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
import './IMyERC20.sol';


contract MyERC20 is IMyERC20 {

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    address public contractOwner;


    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);


    mapping(address => uint256) balances;

    mapping(address => mapping (address => uint256)) allowed;

    uint256 totalSupply_;

    using SafeMath for uint256;


   constructor(string memory _name, string memory _symbol) public {
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, 10000);
        contractOwner = msg.sender;
    }
    
    function mint() public override returns (bool){
        return _mint(msg.sender, 5);
    }
    
    function mintTo(address to, uint256 amount) public override returns(bool){
        require(msg.sender == contractOwner, "Only owner can mint any number of tokens.");
        return _mint(to, amount);
    }
    
    function setOwner(address newOwner) public override returns(bool){
         require(msg.sender == contractOwner, "Only owner");
         contractOwner = newOwner;
         return true;
    }
    
    function _mint(address to, uint256 amount) internal returns(bool){
        uint256 minted = amount*10**uint256(decimals);
        totalSupply_ += minted;
        balances[to] += minted;
        return true;
    }
    
    

    function totalSupply() public override view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address tokenOwner) public override view returns (uint256) {
        return balances[tokenOwner];
    }

    function transfer(address receiver, uint256 numTokens) public override returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(numTokens);
        balances[receiver] = balances[receiver].add(numTokens);
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    function approve(address delegate, uint256 numTokens) public override returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function allowance(address owner, address delegate) public override view returns (uint) {
        return allowed[owner][delegate];
    }

    function transferFrom(address owner, address buyer, uint256 numTokens) public override returns (bool) {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);

        balances[owner] = balances[owner].sub(numTokens);
        allowed[owner][msg.sender] = allowed[owner][msg.sender].sub(numTokens);
        balances[buyer] = balances[buyer].add(numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
}

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
}

