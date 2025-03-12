pragma solidity ^0.4.21;

import 'zeppelin-solidity/contracts/token/ERC20/BurnableToken.sol';
import "zeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "zeppelin-solidity/contracts/ownership/Claimable.sol";

contract LuckchemyToken is BurnableToken, StandardToken, Claimable {

    bool public released = false;

    string public constant name = "Luckchemy";

    string public constant symbol = "LUK";

    uint8 public constant decimals = 8;

    uint256 public CROWDSALE_SUPPLY;

    uint256 public OWNERS_AND_PARTNERS_SUPPLY;

    address public constant OWNERS_AND_PARTNERS_ADDRESS = 0x603a535a1D7C5050021F9f5a4ACB773C35a67602;

    // Index of unique addresses
    uint256 public addressCount = 0;

    // Map of unique addresses
    mapping(uint256 => address) public addressMap;
    mapping(address => bool) public addressAvailabilityMap;

    //blacklist of addresses (product/developers addresses) that are not included in the final Holder lottery
    mapping(address => bool) public blacklist;

    // service agent for managing blacklist
    address public serviceAgent;

    event Release();
    event BlacklistAdd(address indexed addr);
    event BlacklistRemove(address indexed addr);

    /**
     * Do not transfer tokens until the crowdsale is over.
     *
     */
    modifier canTransfer() {
        require(released || msg.sender == owner);
        _;
    }

    /*
     * modifier which gives specific rights to serviceAgent
     */
    modifier onlyServiceAgent(){
        require(msg.sender == serviceAgent);
        _;
    }


    function LuckchemyToken() public {

        totalSupply_ = 1000000000 * (10 ** uint256(decimals));
        CROWDSALE_SUPPLY = 700000000 * (10 ** uint256(decimals));
        OWNERS_AND_PARTNERS_SUPPLY = 300000000 * (10 ** uint256(decimals));

        addAddressToUniqueMap(msg.sender);
        addAddressToUniqueMap(OWNERS_AND_PARTNERS_ADDRESS);

        balances[msg.sender] = CROWDSALE_SUPPLY;

        balances[OWNERS_AND_PARTNERS_ADDRESS] = OWNERS_AND_PARTNERS_SUPPLY;

        owner = msg.sender;

        Transfer(0x0, msg.sender, CROWDSALE_SUPPLY);

        Transfer(0x0, OWNERS_AND_PARTNERS_ADDRESS, OWNERS_AND_PARTNERS_SUPPLY);
    }

    function transfer(address _to, uint256 _value) public canTransfer returns (bool success) {
        //Add address to map of unique token owners
        addAddressToUniqueMap(_to);

        // Call StandardToken.transfer()
        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public canTransfer returns (bool success) {
        //Add address to map of unique token owners
        addAddressToUniqueMap(_to);

        // Call StandardToken.transferForm()
        return super.transferFrom(_from, _to, _value);
    }

    /**
    *
    * Release the tokens to the public.
    * Can be called only by owner which should be the Crowdsale contract
    * Should be called if the crowdale is successfully finished
    *
    */
    function releaseTokenTransfer() public onlyOwner {
        released = true;
        Release();
    }

    /**
     * Add address to the black list.
     * Only service agent can do this
     */
    function addBlacklistItem(address _blackAddr) public onlyServiceAgent {
        blacklist[_blackAddr] = true;

        BlacklistAdd(_blackAddr);
    }

    /**
    * Remove address from the black list.
    * Only service agent can do this
    */
    function removeBlacklistItem(address _blackAddr) public onlyServiceAgent {
        delete blacklist[_blackAddr];
    }

    /**
    * Add address to unique map if it is not added
    */
    function addAddressToUniqueMap(address _addr) private returns (bool) {
        if (addressAvailabilityMap[_addr] == true) {
            return true;
        }

        addressAvailabilityMap[_addr] = true;
        addressMap[addressCount++] = _addr;

        return true;
    }

    /**
    * Get address by index from map of unique addresses
    */
    function getUniqueAddressByIndex(uint256 _addressIndex) public view returns (address) {
        return addressMap[_addressIndex];
    }

    /**
    * Change service agent
    */
    function changeServiceAgent(address _addr) public onlyOwner {
        serviceAgent = _addr;
    }

}