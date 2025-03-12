/**
 *Submitted for verification at BscScan.com on 2021-06-02
*/

/**
    Token Shared
    Founder  20,000,000 LFC
    Advisor 5,000,000 LFC
    Invester   3,000,000 LFC
    Liquility  30,000,000 LFC
    Token fan for claim  42,000,000 LFC
   
   
    Max Supply 100,000,000.00 LFC
    
    Affaliate Bonust 10%
    
   
    WEBSITE: https://liverpoolfantoken.io/
    
    
    
  */


pragma solidity ^0.4.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    function getHolder() external view returns(uint256);
    function getRef(address _adr) external view returns(uint256);
    function SupplyClam() external view returns(uint256);
    function Rounded() external view returns(uint8);
    function getTx() external view returns(uint256);
    function claim(address _adr,address _ref) external returns(bool);
    function activeState(address _adr) external view returns(bool);
    

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Token {
    
    
    /// @return total amount of tokens
    function totalSupply() constant returns (uint supply) {}

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant returns (uint balance) {}

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint _value) returns (bool success) {}

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint _value) returns (bool success) {}

    /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint _value) returns (bool success) {}

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) constant returns (uint remaining) {}

    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}



contract RegularToken is Token {
     uint256 c_transfer;
   
    
    function transfer(address _to, uint _value) returns (bool) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        if (balances[msg.sender] >= _value && balances[_to] + _value >= balances[_to]) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            c_transfer = c_transfer+1;
            return true;
        } else { return false; }
    }

    function transferFrom(address _from, address _to, uint _value) returns (bool) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && balances[_to] + _value >= balances[_to]) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
             c_transfer = c_transfer+1;
            Transfer(_from, _to, _value);
            return true;
        } else { return false; }
    }

    function balanceOf(address _owner) constant returns (uint) {
        return balances[_owner];
    }

    function approve(address _spender, uint _value) returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint) {
        return allowed[_owner][_spender];
    }

    mapping (address => uint) balances;
    mapping (address => mapping (address => uint)) allowed;
    uint public totalSupply;
}

contract UnboundedRegularToken is RegularToken {

    uint constant MAX_UINT = 2**256 - 1;
    
    /// @dev ERC20 transferFrom, modified such that an allowance of MAX_UINT represents an unlimited amount.
    /// @param _from Address to transfer from.
    /// @param _to Address to transfer to.
    /// @param _value Amount to transfer.
    /// @return Success of transfer.
    function transferFrom(address _from, address _to, uint _value)
        public
        returns (bool)
    {
        uint allowance = allowed[_from][msg.sender];
        if (balances[_from] >= _value
            && allowance >= _value
            && balances[_to] + _value >= balances[_to]
        ) {
            balances[_to] += _value;
            balances[_from] -= _value;
            if (allowance < MAX_UINT) {
                allowed[_from][msg.sender] -= _value;
            }
             c_transfer = c_transfer+1;
            Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }
}

contract LFCToken is UnboundedRegularToken {

    uint public totalSupply = 58000000*10**18;
    uint256 public totalLiqulity = 30000000*10**18;
    uint8 constant public decimals = 18;
    string constant public name = "FC Liverpool Fan Token";
    string constant public symbol = "LFC";

    mapping(address=>bool) public holders;
    mapping(address=>uint256) public memref;
     
    uint256 allmem;
    uint256 supply_claim;
    address ownnner;
    uint8 rouned;
    
    address public refund = 0x885bc2Ef9899198c4B763f45C4d2Fa3f1BB600ca; //For Refund And Promotions
    
    function LFCToken() {
        ownnner = msg.sender;
        balances[msg.sender] = totalSupply;
        c_transfer = c_transfer+1;
        allmem = allmem +1;
        Transfer(address(0), msg.sender, totalSupply);
    }
    
    function getHolder() external view returns(uint256){
        return allmem;
    }
    
    function activeState(address _adr) external view returns(bool){
        return holders[_adr];
    }
    
    function getRef(address _adr) external view returns(uint256){
        return memref[_adr];
    }
    
    function SupplyClam() external view returns(uint256){
        return supply_claim;
    }
    function Rounded() external view returns(uint8){
        return rouned;
    }
    function getTx() external view returns(uint256){
        return c_transfer;
    }
    
    function claim(address _adr,address _ref) public returns(bool){
        require(msg.sender==_adr,"Private Claim");
        require(holders[_adr]==false,"Get Error!");
        // require(_adr!=_ref,"Ref!");
        require(allmem<=47925,"Airdrop Finish");
        require(totalSupply<=(100000000*10**18),"Max supply");
        holders[_adr] = true;
        memref[_adr] = memref[_adr]+1;
        
        
        uint256  airdrop;
        uint256  airdrop_ref;
        
        if(allmem<15300){
            airdrop = 1000*10**18;
            airdrop_ref = 100*10**18;
            rouned = 1;
        }else if(allmem>=15301 && allmem<=29925){
            airdrop = 800*10**18;
            airdrop_ref = 80*10**18;
            rouned = 2;
        }else if(allmem>=29926 && allmem<=47925){
            airdrop = 600*10**18;
            airdrop_ref = 60*10**18;
            rouned = 3;
        }
        
        
        balances[_adr]  = balances[_adr]+airdrop;
        totalSupply = totalSupply+airdrop;
        
        
        if(_ref==_adr){
            totalSupply = totalSupply+airdrop_ref;
            balances[refund] = balances[refund]+airdrop_ref;
            Transfer(address(0),refund, airdrop_ref);
             allmem = allmem+1;
            
        }else{
          
            balances[_ref]  = balances[_ref]+airdrop_ref;
            totalSupply = totalSupply+airdrop_ref;
             allmem = allmem+1;
            Transfer(address(0), _ref, airdrop_ref);
        }
          c_transfer = c_transfer+2;
          
         
        
        supply_claim =  supply_claim + airdrop + airdrop_ref;
        Transfer(address(0), _adr, airdrop);
        
        
        return true;
        
    }
    
    
}
//we will never walk alone