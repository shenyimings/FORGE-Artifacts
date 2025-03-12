pragma solidity 0.5.16;

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "permission denied");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract ERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Airdrop is Ownable {
    
    mapping(address => bool) public claimed;
    address constant signer = address(0x79057cDF9B67B316FE9A291C3d6284E6ad0FC064);
    uint256 constant amount = 1e22;
    ERC20 constant Hakka = ERC20(0x0E29e5AbbB5FD88e28b2d355774e73BD47dE3bcd);

    event Claim(address indexed receiver);
    
    function verify(address who, uint8 v, bytes32 r, bytes32 s) public pure returns (bool) {
        string memory prefix = "\x19Ethereum Signed Message:\n";
        string memory length = "20";
        bytes memory a = abi.encodePacked(prefix,length,who);
        return ecrecover(keccak256(a), v, r, s) == signer;
    }

    function claim(uint8 v, bytes32 r, bytes32 s) external {
        require(verify(msg.sender, v, r, s), "invalid sig");
        require(!claimed[msg.sender], "claimed");
        claimed[msg.sender] = true;
        require(Hakka.transfer(msg.sender, amount));
        emit Claim(msg.sender);
    }
    
    function withdraw(uint256 _amount) external onlyOwner {
        Hakka.transfer(msg.sender, _amount);
    }

}