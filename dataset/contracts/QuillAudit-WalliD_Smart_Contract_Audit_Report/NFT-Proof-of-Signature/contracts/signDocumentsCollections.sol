// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract SimpleAccessControl {

    mapping (address => uint8) internal _owners;

    modifier isOwner() {
        require(_owners[msg.sender] == 10, "ERR_NOT_OWNER");
        _;
    }
    
    //constructor(address[] payable ownerAdress) {
    //    _owner = ownerAdress; 
    //}

    constructor() {
        _owners[msg.sender] = 10;
    }

    function addOwnership(address payable newOwner) public isOwner {
        require(newOwner != address(0), "ERR_ZERO_ADDR");
       _owners[newOwner] = 10;
    }
    
    function removeOwnership(address payable newOwner) public isOwner {
        require(newOwner != address(0), "ERR_ZERO_ADDR");
       _owners[newOwner] = 0;
    }
}

contract WalliDProofOfSignatureNFTs  is ERC1155, SimpleAccessControl 
{
    
    uint256 private _id = 1;
    string public name;
    string private _contractURI;

    mapping(uint256 => DocumentInfo) private _idsToDocument;
    mapping(bytes => uint256) private _hashDocToNftId;
    //mapping(address => uint256[]) private  _signersToIds;

    struct DocumentInfo 
    {
        address[] signers;
        bytes envelopeId;
        bytes documentHash;
        uint256 nftId;
    }

    constructor() ERC1155("https://api.wallid.io/api/v1/metadata/detail/{id}")
    {
        _contractURI = "https://api.wallid.io/api/v1/metadata/";
        name = "WalliD PoS NFTs";
    }

    function lastIndex() public view returns (uint256) {
        return _id;
    }

    // get nft info based on id
    function getSignersInfo (uint256 id ) public view returns (address[] memory, bytes memory, bytes memory) {
        return (_idsToDocument[id].signers, _idsToDocument[id].envelopeId, _idsToDocument[id].documentHash);    
    }

     // get nft info based on document hash
     function getSignersInfo (bytes memory docHash ) public view returns (address[] memory, bytes memory, bytes memory, uint256 ) 
     {
        uint256 id = _hashDocToNftId[docHash];
        return (_idsToDocument[id].signers, _idsToDocument[id].envelopeId, _idsToDocument[id].documentHash, id);    
     }

    function mintDocument( address[] memory signers, bytes memory envelopeId, bytes memory docHash   ) public isOwner  returns (uint256) 
    {
        
        // store document struct
        _idsToDocument[_id].signers = signers;
        _idsToDocument[_id].envelopeId = envelopeId;
        _idsToDocument[_id].documentHash = docHash;
        _idsToDocument[_id].nftId = _id;
        // hash document to id
        _hashDocToNftId[docHash] = _id;
     
        for (uint i = 0; i<signers.length; i++) 
        {
            _mint(signers[i], _id, 1, "");
        }

        _id = _id + 1;
        return _id;
    }

    /* Metadata information */
    /* set uri of itens */
    function setURI(string memory newuri)  public  isOwner() returns (bool){
        _setURI(newuri);
        return true;
    }

    /* setContract uri  */
    function setContractURI(string memory newuri)  public  isOwner() returns (bool)
    {
        _contractURI = newuri;
        return true;
    }

    /* set Collection name  */
    function setCollectionName(string memory _name)  public  isOwner() returns (bool)
    {
        name = _name;
        return true;
    }

    /* Contract URL for with metada information  */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

}
