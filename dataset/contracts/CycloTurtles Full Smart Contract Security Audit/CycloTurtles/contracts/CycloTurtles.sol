// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// Version: 0.4
contract CycloTurtles is ERC721, Ownable { 
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct VITSaleConfig {
        uint256 price; // 0.08
        bool isActive;
        uint256 maxWallet;
        uint256 count;
    }
    struct PresaleConfig {
        uint256 price; // 0.1 ETH
        bool isActive;
        uint256 maxWallet;
        uint256 count;
    }
    struct SaleConfig {
        uint256 price; // 0.15 ETH
        bool isActive;
        uint256 maxWallet;
        uint256 count;
    }

    VITSaleConfig public vitSaleConfig = VITSaleConfig(80000000000000000, false, 3, 0);
    PresaleConfig public presaleConfig = PresaleConfig(100000000000000000, false, 5, 0);
    SaleConfig public saleConfig = SaleConfig(150000000000000000, false, 10, 0);

    uint256 public maxTotalSupply = 7777;
    uint256 public maxGiftSupply = 155;
    uint256 public maxPublicSupply = 4289;
    uint256 public maxVITSupply = 1111;
    uint256 public maxPresaleSupply = 2222;

    uint256 public totalSupplyCount;
    uint256 public giftCount;
    
    string private baseURI;
    string private unrevealedURI;
    bool public revealed = false;
    bool public isBurnEnabled;

    mapping(address => bool) private _vitList;
    mapping(address => bool) private _presaleList;
    mapping(address => uint256) public _vitClaimed;
    mapping(address => uint256) public _presaleClaimed;
    mapping(address => uint256) public _saleClaimed;
    mapping(address => uint256) public _giftClaimed;

    enum WorkflowStatus {
        Paused,
        VITSale,
        Presale,
        Sale,
        SoldOut
    }
    WorkflowStatus public workflow;

    event ChangeBaseURI(string _baseURI);
    event StartSale(string _sale);
    event UpdatedIsBurnEnabled(bool _isBurnEnabled);
    event Mint(address _minter, uint256 _amount, string _type);
    event AddToList(address _address, string _list);
    event RemoveFromList(address _address, string _list);
    event Burn(uint _tokenId);

    constructor() ERC721("CycloTurtles", "TURTLES") {} // "CycloTurtles", "TURTLES"

    // Admin Functions

    function getTotalSupply() public view returns (uint256) {
        return totalSupplyCount;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "CycloTurtles: URI query for nonexistent token");
        
        if (revealed == false) {
            return unrevealedURI;
        } else {
            if (bytes(baseURI).length > 0) {
                return string(abi.encodePacked(baseURI, tokenId));
            } else {
                return super.tokenURI(tokenId);
            }
        }
    }

    function setUnrevealedURI(string calldata _unrevealedURI) external onlyOwner {
        unrevealedURI = _unrevealedURI;
    }

    function setBaseURI(string calldata _tokenBaseURI) external onlyOwner {
        baseURI = _tokenBaseURI;
        emit ChangeBaseURI(_tokenBaseURI);
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    // Whitelist Functions

    function addToVITList(address[] calldata _addresses)
        external
        onlyOwner
    {
        for(uint i = 0; i < _addresses.length; i++) {
            require(
                _addresses[i] != address(0),
                "CycloTurtles: Can't add 0 address"
            );
            if(_vitList[_addresses[i]] == false) {
                _vitList[_addresses[i]] = true;
            }
            emit AddToList(_addresses[i], "VIT");
        }
    }

    function removeFromVITList(address[] calldata _addresses)
        external
        onlyOwner
    {
        for(uint i = 0; i < _addresses.length; i++) {
            require(
                _addresses[i] != address(0),
                "CycloTurtles: Can't add a zero address"
            );
            if(_vitList[_addresses[i]] == true) {
                _vitList[_addresses[i]] = false;
            }
            emit RemoveFromList(_addresses[i], "VIT");
        }
    }

    function addToPresaleList(address[] calldata _addresses)
        external
        onlyOwner
    {
        for(uint i = 0; i < _addresses.length; i++) {
            require(
                _addresses[i] != address(0),
                "CycloTurtles: Can't add 0 address"
            );
            if(_presaleList[_addresses[i]] == false) {
                _presaleList[_addresses[i]] = true;
            }
            emit AddToList(_addresses[i], "Presale");
        }
    }

    function removeFromPresaleList(address[] calldata _addresses)
        external
        onlyOwner
    {
        for(uint i = 0; i < _addresses.length; i++) {
            require(
                _addresses[i] != address(0),
                "CycloTurtles: Can't add a zero address"
            );
            if(_presaleList[_addresses[i]] == true) {
                _presaleList[_addresses[i]] = false;
            }
            emit RemoveFromList(_addresses[i], "Presale");
        }
    }

    function isOnVITSale (address _address) external view returns (bool) {
        return _vitList[_address];
    }

    function isOnPresale (address _address) external view returns (bool) {
        return _presaleList[_address];
    }

    // Sale Workflow Functions

    function getWorkflowStatus() public view returns(uint) {
        if (workflow == WorkflowStatus.Paused) {
            return 1;
        } else if (workflow == WorkflowStatus.VITSale){
            return 2;
        } else if (workflow == WorkflowStatus.Presale) {
            return 3;
        } else if (workflow == WorkflowStatus.Sale) {
            return 4;
        } else { //workflow == WorkflowStatus.SoldOut
            return 5;
        }
    }
    
    function pauseSales() external onlyOwner {
        workflow = WorkflowStatus.Paused;
        vitSaleConfig.isActive = false;
        presaleConfig.isActive = false;
        saleConfig.isActive = false;
    }

    function startVITSale() external onlyOwner {
        require(
            workflow == WorkflowStatus.Paused,
            "CycloTurtles: VIT sale can only start when workflow = paused"
        );
        vitSaleConfig.isActive = true;
        emit StartSale("VIT");

        workflow = WorkflowStatus.VITSale;
    }

    function startPresale() external onlyOwner {
        require(
            workflow == WorkflowStatus.VITSale,
            "CycloTurtles: Must be in VIT sale to start presale"
        );
        vitSaleConfig.isActive = false;
        presaleConfig.isActive = true;
        emit StartSale("Presale");
        workflow = WorkflowStatus.Presale;
    }

    function startPublicSale() external onlyOwner {
        require(
            workflow == WorkflowStatus.Presale,
            "CycloTurtles: Must be in presale to start public sale"
        );
        presaleConfig.isActive = false;
        saleConfig.isActive = true;
        emit StartSale("Public");
        workflow = WorkflowStatus.Sale;
    }

    function setIsBurnEnabled(bool _isBurnEnabled) external onlyOwner {
        isBurnEnabled = _isBurnEnabled;
        emit UpdatedIsBurnEnabled(_isBurnEnabled);
    }

    // Minting & Burn Functions

    function giftMint(address _address, uint256 _amount)
        external
        onlyOwner
    {
        require(
            _address != address(0),
            "CycloTurtles: Cannot send to 0 address"
        );
        require(
            totalSupplyCount + _amount <= maxTotalSupply,
            "CycloTurtles: max total supply exceeded"
        );
        require(
            giftCount + _amount <= maxGiftSupply,
            "CycloTurtles: max gift supply exceeded"
        );

        uint256 _newTokenId;
        for (uint i = 0; i < _amount; i++) {
            _tokenIds.increment();
            _newTokenId = _tokenIds.current();
            _safeMint(_address, _newTokenId);
            _giftClaimed[_address] += 1;
            totalSupplyCount += 1;
            giftCount += 1;
            emit Mint(_address, _amount, "Gift");
        }
    }

    function vitMint(uint256 _amount) external payable {
        require(
            vitSaleConfig.isActive == true,
            "CycloTurtles: Sale must be active to mint"
        );
        require(
            _vitList[msg.sender] == true,
            "CycloTurtles: Caller is not on the VIT list"
        );
        require(
            _vitClaimed[msg.sender] + _amount <= vitSaleConfig.maxWallet,
            "CycloTurtles: Can only mint 3 per wallet"
        );
        require(
            vitSaleConfig.count + _amount <= maxVITSupply,
            "CycloTurtles: Cannot exceed max supply"
        );
        require(
            vitSaleConfig.price * _amount <= msg.value,
            "CycloTurtles: Ether value sent is too low"
        );
        uint256 _newTokenId;
        for(uint i = 0; i < _amount; i++) {
            _tokenIds.increment();
            _newTokenId = _tokenIds.current();
            _safeMint(msg.sender, _newTokenId);
            _vitClaimed[msg.sender] += 1;
            totalSupplyCount += 1;
            vitSaleConfig.count += 1;
        }
        emit Mint(msg.sender, _amount, "VIT");
    }

    function presaleMint (uint256 _amount) external payable {
        require(
            presaleConfig.isActive == true,
            "CycloTutrles: Sale must be active to mint"
        );
        require(
            _presaleList[msg.sender] == true,
            "CycloTurtles: Caller is not on the presale list"
        );
        require(
            _presaleClaimed[msg.sender] + _amount <= presaleConfig.maxWallet,
            "CycloTurtles: Can only mint 2 tokens"
        );
        require(
            presaleConfig.count + _amount <= maxPresaleSupply,
            "CycloTurtles: Cannot exceed max presale supply"
        );
        require(
            presaleConfig.price * _amount <= msg.value,
            "CycloTurtles: Ether value sent is too low"
        );
        uint256 _newTokenId;
        for(uint i; i < _amount; i++) {
            _tokenIds.increment();
            _newTokenId = _tokenIds.current();
            _safeMint(msg.sender, _newTokenId);
            _presaleClaimed[msg.sender] += 1;
            presaleConfig.count += 1;
            totalSupplyCount += 1;
        }
        emit Mint(msg.sender, _amount, "Presale");
    }

    function saleMint(uint256 _amount) external payable {
        require(
            saleConfig.isActive == true,
            "CycloTurtles: Sale must be active to mint"
        );
        require(
            _amount <= 5,
            "CycloTurtles: Can only mint 5 tokens per txn"
        );
        require(
            _saleClaimed[msg.sender] + _amount <= saleConfig.maxWallet,
            "CycloTurtles: Can only mint 10 tokens per wallet"
        );
        require(
            saleConfig.count + _amount <= maxPublicSupply,
            "CycloTurtles: Cannot exceed max total supply"
        );
        require(
            saleConfig.price * _amount <= msg.value,
            "CycloTurtles: Ether value sent is too low"
        );
        uint256 _newTokenId;
        for(uint i; i < _amount; i++) {
            _tokenIds.increment();
            _newTokenId = _tokenIds.current();
            _safeMint(msg.sender, _newTokenId);
            _saleClaimed[msg.sender] += 1;
            totalSupplyCount += 1;
            saleConfig.count += 1;
        }
        emit Mint(msg.sender, _amount, "Public sale");
        if(totalSupplyCount == maxTotalSupply) {
            workflow = WorkflowStatus.SoldOut;
            saleConfig.isActive = false;
        }
    }

    function burn(uint256 tokenId) external {
        require(
            isBurnEnabled == true,
            "CycloTurtles: Burning diasabled"
        );
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "CycloTurtles: Caller is not owner or approved"
        );
        _burn(tokenId);
        totalSupplyCount -= 1;
        emit Burn(tokenId);
    }

    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}