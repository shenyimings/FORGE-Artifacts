pragma solidity ^0.8.0;
import "./IPaidProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PaidProof is IPaidProof, Ownable {
    uint public price; // Price in ETH to use a function with the needsPayment modifier
    mapping(uint => bool) public allowedIssuers; // Whitelist of issuers

    constructor() {}

    function setPrice(uint newPrice) public onlyOwner {
            price = newPrice;
    }

    function collectPayments() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    modifier needsPayment() {
        require(msg.value >= price, "Missing payment");
        _;
    }

    function allowIssuers(uint[] memory issuerAddresses) public onlyOwner {
        uint8 i;
        for (i = 0; i < issuerAddresses.length; i++) {
            allowedIssuers[issuerAddresses[i]] = true;  
        }
    }

    function revokeIssuers(uint[] memory issuerAddresses) public onlyOwner {
        uint8 i;
        for (i = 0; i < issuerAddresses.length; i++) {
            allowedIssuers[issuerAddresses[i]] = false;  
        }            
    }

    function isValidIssuer(uint issuerAddress) public view returns (bool) {
        return allowedIssuers[issuerAddress];       
    }
}
