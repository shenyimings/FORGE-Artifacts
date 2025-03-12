// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC721Upgradeable, IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import {IERC721ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IMaArtProxy} from "./interfaces/IMaArtProxy.sol";
import {IPair} from "./interfaces/IPair.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IMaGaugeStruct.sol";


contract MaLPNFT is Initializable, IERC721Upgradeable, IERC721MetadataUpgradeable {


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address to, uint tokenId, address maGauge);
    event Burn(uint tokenId, address maGauge);
    event NewMaLPNFT(address maGauge, address pair, bool isStable, string maGaugeName, string maGaugeSymbol);
    event KillMaLPNFT(address maGauge);
    event ReviveMaLPNFT(address maGauge);


    /*//////////////////////////////////////////////////////////////
                               Initialize
    //////////////////////////////////////////////////////////////*/

    address public team;
    address public voter;
    address public artProxy;

    uint maxBonusEpoch;
    uint maxBonusPercent;
    uint gaugesQtty;
    uint[] weightsByEpochs;
    uint public constant PRECISSION = 1000;



    /// @dev Mapping of address to maGauge struct
    mapping(address => IMaGaugeStruct.MaGauge) public maGauges; // epoch -> unsigned point

    /// @dev Mapping of gaugeId to Gauge Address
    mapping(uint => address) public gaugeIdToAddress; // epoch -> unsigned point
    
    /// @dev Mapping of uint to maGauge address 
    mapping(uint => address) public tokenToGauge; // epoch -> unsigned point

    /// @dev Mapping of interface id to bool about whether or not it's supported
    mapping(bytes4 => bool) internal supportedInterfaces;

    /// @dev ERC165 interface ID of ERC165
    bytes4 internal constant ERC165_INTERFACE_ID = 0x01ffc9a7;

    /// @dev ERC165 interface ID of ERC721
    bytes4 internal constant ERC721_INTERFACE_ID = 0x80ac58cd;

    /// @dev ERC165 interface ID of ERC721Metadata
    bytes4 internal constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;

    /// @dev Current count of token
    uint internal tokenId;

    /// @dev reentrancy guard
    bool internal _entered;


    /**
     * @notice Contract Initialize
     * @param art_proxy `art_proxy` address
     */
    function initialize(
        address art_proxy
    ) public initializer {
        voter = msg.sender;
        team = msg.sender;
        artProxy = art_proxy;

        supportedInterfaces[ERC165_INTERFACE_ID] = true;
        supportedInterfaces[ERC721_INTERFACE_ID] = true;
        supportedInterfaces[ERC721_METADATA_INTERFACE_ID] = true;

        weightsByEpochs = [1000,1200,1400,1600,1800,2000];

        // mint-ish
        emit Transfer(address(0), address(this), tokenId);
        // burn-ish
        emit Transfer(address(this), address(0), tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier nonReentrant() {
        require(!_entered, "No re-entrancy");
        _entered = true;
        _;
        _entered = false;
    }


    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string constant public name = "Maturity NFTs";
    string constant public symbol = "maNFT";
    string constant public version = "1.0.0";

    function setTeam(address _team) external {
        require(msg.sender == team);
        team = _team;
    }

    function setVoter(address _voter) external {
        require(msg.sender == team);
        voter = _voter;
    }

    function setBoostParams(uint _maxBonusEpoch, uint _maxBonusPercent) external {
        require(msg.sender == team);
        maxBonusEpoch = _maxBonusEpoch;
        maxBonusPercent = _maxBonusPercent;
    }

    function setArtProxy(address _proxy) external {
        require(msg.sender == team);
        artProxy = _proxy;
    }

    /// @dev Returns current token URI metadata
    /// @param _tokenId Token ID to fetch URI for.
    function tokenURI(uint _tokenId) external view returns (string memory) {
        require(idToOwner[_tokenId] != address(0), "Query for nonexistent token");
        
        return IMaArtProxy(artProxy)._tokenURI(_tokenId);
    }

    function getWeightByEpoch() public view returns (uint[] memory) {
        return weightsByEpochs;
    }

    function totalMaLevels() public view returns(uint) {
        return weightsByEpochs.length;
    }

    function tokenIdView() external view returns (uint) {
        return tokenId;
    }

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from NFT ID to the address that owns it.
    mapping(uint => address) internal idToOwner;

    /// @dev Mapping from owner address to count of his tokens.
    mapping(address => uint) internal ownerToNFTokenCount;

    /// @dev Returns the address of the owner of the NFT.
    /// @param _tokenId The identifier for an NFT.
    function ownerOf(uint _tokenId) public view returns (address) {
        return idToOwner[_tokenId];
    }

    /// @dev Returns the number of NFTs owned by `_owner`.
    ///      Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
    /// @param _owner Address for whom to query the balance.
    function _balance(address _owner) internal view returns (uint) {
        return ownerToNFTokenCount[_owner];
    }

    /// @dev Returns the number of NFTs owned by `_owner`.
    ///      Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
    /// @param _owner Address for whom to query the balance.
    function balanceOf(address _owner) external view returns (uint) {
        return _balance(_owner);
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from NFT ID to approved address.
    mapping(uint => address) internal idToApprovals;

    /// @dev Mapping from owner address to mapping of operator addresses.
    mapping(address => mapping(address => bool)) internal ownerToOperators;

    mapping(uint => uint) public ownership_change;

    /// @dev Get the approved address for a single NFT.
    /// @param _tokenId ID of the NFT to query the approval of.
    function getApproved(uint _tokenId) external view returns (address) {
        return idToApprovals[_tokenId];
    }

    /// @dev Checks if `_operator` is an approved operator for `_owner`.
    /// @param _owner The address that owns the NFTs.
    /// @param _operator The address that acts on behalf of the owner.
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return (ownerToOperators[_owner])[_operator];
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Set or reaffirm the approved address for an NFT. The zero address indicates there is no approved address.
    ///      Throws unless `msg.sender` is the current NFT owner, or an authorized operator of the current owner.
    ///      Throws if `_tokenId` is not a valid NFT. (NOTE: This is not written the EIP)
    ///      Throws if `_approved` is the current owner. (NOTE: This is not written the EIP)
    /// @param _approved Address to be approved for the given NFT ID.
    /// @param _tokenId ID of the token to be approved.
    function approve(address _approved, uint _tokenId) public {
        address owner = idToOwner[_tokenId];
        // Throws if `_tokenId` is not a valid NFT
        require(owner != address(0));
        // Throws if `_approved` is the current owner
        require(_approved != owner);
        // Check requirements
        bool senderIsOwner = (idToOwner[_tokenId] == msg.sender);
        bool senderIsApprovedForAll = (ownerToOperators[owner])[msg.sender];
        require(senderIsOwner || senderIsApprovedForAll);
        // Set the approval
        idToApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    /// @dev Enables or disables approval for a third party ("operator") to manage all of
    ///      `msg.sender`'s assets. It also emits the ApprovalForAll event.
    ///      Throws if `_operator` is the `msg.sender`. (NOTE: This is not written the EIP)
    /// @notice This works even if sender doesn't own any tokens at the time.
    /// @param _operator Address to add to the set of authorized operators.
    /// @param _approved True if the operators is approved, false to revoke approval.
    function setApprovalForAll(address _operator, bool _approved) external {
        // Throws if `_operator` is the `msg.sender`
        assert(_operator != msg.sender);
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /* TRANSFER FUNCTIONS */
    /// @dev Clear an approval of a given address
    ///      Throws if `_owner` is not the current owner.
    function _clearApproval(address _owner, uint _tokenId) internal {
        // Throws if `_owner` is not the current owner
        assert(idToOwner[_tokenId] == _owner);
        if (idToApprovals[_tokenId] != address(0)) {
            // Reset approvals
            idToApprovals[_tokenId] = address(0);
        }
    }

    /// @dev Returns whether the given spender can transfer a given token ID
    /// @param _spender address of the spender to query
    /// @param _tokenId uint ID of the token to be transferred
    /// @return bool whether the msg.sender is approved for the given token ID, is an operator of the owner, or is the owner of the token
    function _isApprovedOrOwner(address _spender, uint _tokenId) internal view returns (bool) {
        address owner = idToOwner[_tokenId];
        bool spenderIsOwner = owner == _spender;
        bool spenderIsApproved = _spender == idToApprovals[_tokenId];
        bool spenderIsApprovedForAll = (ownerToOperators[owner])[_spender];
        return spenderIsOwner || spenderIsApproved || spenderIsApprovedForAll;
    }

    function isApprovedOrOwner(address _spender, uint _tokenId) external view returns (bool) {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// @dev Exeute transfer of a NFT.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
    ///      address for this NFT. (NOTE: `msg.sender` not allowed in internal function so pass `_sender`.)
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_tokenId` is not a valid NFT.
    function _transferFrom(
        address _from,
        address _to,
        uint _tokenId,
        address _sender
    ) internal {
        // Check requirements
        require(_isApprovedOrOwner(_sender, _tokenId));
        // Clear approval. Throws if `_from` is not the current owner
        _clearApproval(_from, _tokenId);
        // Remove NFT. Throws if `_tokenId` is not a valid NFT
        _removeTokenFrom(_from, _tokenId);
        // Add NFT
        _addTokenTo(_to, _tokenId);
        // Set the block of ownership transfer (for Flash NFT protection)
        ownership_change[_tokenId] = block.number;
        // Log the transfer
        emit Transfer(_from, _to, _tokenId);
    }

    /// @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved address for this NFT.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_tokenId` is not a valid NFT.
    /// @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
    ///        they maybe be permanently lost.
    /// @param _from The current owner of the NFT.
    /// @param _to The new owner.
    /// @param _tokenId The NFT to transfer.
    function transferFrom(
        address _from,
        address _to,
        uint _tokenId
    ) external {
        _transferFrom(_from, _to, _tokenId, msg.sender);
    }

    /// @dev Transfers the ownership of an NFT from one address to another address.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the
    ///      approved address for this NFT.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_tokenId` is not a valid NFT.
    ///      If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
    ///      the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
    /// @param _from The current owner of the NFT.
    /// @param _to The new owner.
    /// @param _tokenId The NFT to transfer.
    function safeTransferFrom(
        address _from,
        address _to,
        uint _tokenId
    ) external {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    function _isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.
        uint size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /// @dev Transfers the ownership of an NFT from one address to another address.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the
    ///      approved address for this NFT.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_tokenId` is not a valid NFT.
    ///      If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
    ///      the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
    /// @param _from The current owner of the NFT.
    /// @param _to The new owner.
    /// @param _tokenId The NFT to transfer.
    /// @param _data Additional data with no specified format, sent in call to `_to`.
    function safeTransferFrom(
        address _from,
        address _to,
        uint _tokenId,
        bytes memory _data
    ) public {
        _transferFrom(_from, _to, _tokenId, msg.sender);

        if (_isContract(_to)) {
            // Throws if transfer destination is a contract which does not implement 'onERC721Received'
            try IERC721ReceiverUpgradeable(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4 response) {
                if (response != IERC721ReceiverUpgradeable(_to).onERC721Received.selector) {
                    revert("ERC721: ERC721Receiver rejected tokens");
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert('ERC721: transfer to non ERC721Receiver implementer');
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Interface identification is specified in ERC-165.
    /// @param _interfaceID Id of the interface
    function supportsInterface(bytes4 _interfaceID) external view returns (bool) {
        return supportedInterfaces[_interfaceID];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Mapping from owner address to mapping of index to tokenIds
    mapping(address => mapping(uint => uint)) internal ownerToNFTokenIdList;

    /// @dev Mapping from NFT ID to index of owner
    mapping(uint => uint) internal tokenToOwnerIndex;

    /// @dev  Get token by index
    function tokenOfOwnerByIndex(address _owner, uint _tokenIndex) external view returns (uint) {
        return ownerToNFTokenIdList[_owner][_tokenIndex];
    }

    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = _balance(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 index; index < tokenCount; index++) {
                result[index] = ownerToNFTokenIdList[_owner][index];
            }
            return result;
        }
    }

    /// @dev Add a NFT to an index mapping to a given address
    /// @param _to address of the receiver
    /// @param _tokenId uint ID Of the token to be added
    function _addTokenToOwnerList(address _to, uint _tokenId) internal {
        uint current_count = _balance(_to);

        ownerToNFTokenIdList[_to][current_count] = _tokenId;
        tokenToOwnerIndex[_tokenId] = current_count;
    }

    /// @dev Add a NFT to a given address
    ///      Throws if `_tokenId` is owned by someone.
    function _addTokenTo(address _to, uint _tokenId) internal {
        // Throws if `_tokenId` is owned by someone
        assert(idToOwner[_tokenId] == address(0));
        // Change the owner
        idToOwner[_tokenId] = _to;
        // Update owner token index tracking
        _addTokenToOwnerList(_to, _tokenId);
        // Change count tracking
        ownerToNFTokenCount[_to] += 1;
    }

    /// @dev Function to mint tokens
    ///      Throws if `_to` is zero address.
    ///      Throws if `_tokenId` is owned by someone.
    /// @param _to The address that will receive the minted tokens.
    /// @param _tokenId The token id to mint.
    /// @return A boolean that indicates if the operation was successful.
    function _mint(address _to, uint _tokenId) internal returns (bool) {
        // Throws if `_to` is zero address
        assert(_to != address(0));
        // Add NFT. Throws if `_tokenId` is owned by someone
        _addTokenTo(_to, _tokenId);
        emit Transfer(address(0), _to, _tokenId);
        return true;
    }

    /// @dev Remove a NFT from an index mapping to a given address
    /// @param _from address of the sender
    /// @param _tokenId uint ID Of the token to be removed
    function _removeTokenFromOwnerList(address _from, uint _tokenId) internal {
        // Delete
        uint current_count = _balance(_from) - 1;
        uint current_index = tokenToOwnerIndex[_tokenId];

        if (current_count == current_index) {
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_count] = 0;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[_tokenId] = 0;
        } else {
            uint lastTokenId = ownerToNFTokenIdList[_from][current_count];

            // Add
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_index] = lastTokenId;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[lastTokenId] = current_index;

            // Delete
            // update ownerToNFTokenIdList
            ownerToNFTokenIdList[_from][current_count] = 0;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[_tokenId] = 0;
        }
    }

    /// @dev Remove a NFT from a given address
    ///      Throws if `_from` is not the current owner.
    function _removeTokenFrom(address _from, uint _tokenId) internal {
        // Throws if `_from` is not the current owner
        assert(idToOwner[_tokenId] == _from);
        // Change the owner
        idToOwner[_tokenId] = address(0);
        // Update owner token index tracking
        _removeTokenFromOwnerList(_from, _tokenId);
        // Change count tracking
        ownerToNFTokenCount[_from] -= 1;
    }

    function _burn(uint _tokenId) internal {

        address owner = ownerOf(_tokenId);

        // Clear approval
        _clearApproval(owner, _tokenId);
        // Remove token
        //_removeTokenFrom(msg.sender, _tokenId);
        _removeTokenFrom(owner, _tokenId);
        
        emit Transfer(owner, address(0), _tokenId);
    }

    

    /*//////////////////////////////////////////////////////////////
                              maNFT LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint( address _to ) external returns(uint _tokenId) {
        require(maGauges[msg.sender].active);

        ++tokenId;
        _tokenId = tokenId;
        _mint(_to, _tokenId);

        tokenToGauge[_tokenId] = msg.sender;
        emit Mint(_to, tokenId, msg.sender);
    }
    
    function maGaugeTokensOfOwner(address _owner, address _gauge) external view returns (uint256[] memory) {
        uint256 tokenCount = _balance(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory _result = new uint256[](tokenCount);
            uint index;
            for (uint256 i; i < tokenCount; i++) {
                if (tokenToGauge[ownerToNFTokenIdList[_owner][i]] == _gauge ) {
                    _result[index] = ownerToNFTokenIdList[_owner][i];
                    index++;
                }
            }
            uint256[] memory result = new uint256[](index);
            for (uint256 i; i < index; i++) {
                result[i] = _result[i];
            }
            return result;
        }
    }

    function maGaugesOfOwner(address _owner) external view returns (address[] memory) {
        uint256 tokenCount = _balance(_owner);
        if (tokenCount == 0) {
            return new address[](0);
        } else {
            address[] memory _result = new address[](tokenCount);
            uint index;
            address _gauge;
            for (uint256 i = 0; i < tokenCount; i++) {
                _gauge = tokenToGauge[ownerToNFTokenIdList[_owner][i]];
                bool exist = false;
                for (uint256 j = 0; j < index; j++) {
                    if(_gauge == _result[j]) exist = true;
                }
                if (!exist) {
                    _result[index] = _gauge;
                    index++;
                }
            }
            address[] memory result = new address[](index);
            for (uint256 i; i < index; i++) {
                result[i] = _result[i];
            }
            return result;
        }
    }

    function burn( uint _tokenId ) external {
        require(maGauges[msg.sender].maGaugeAddress == msg.sender); // necessary to exit positions.
        require (tokenToGauge[_tokenId] == msg.sender);

        _burn(_tokenId);
        tokenToGauge[_tokenId] = address(0);
        emit Burn(tokenId, msg.sender);
    }
    
    function fromThisGauge(uint _tokenId) external view returns(bool) {
        require(maGauges[msg.sender].maGaugeAddress == msg.sender); // necessary to exit positions.
        require (tokenToGauge[_tokenId] == msg.sender);
        return true;
    }

    function addGauge( address _maGaugeAddress, address _pool, address _token0, address _token1, uint _maGaugeId) external {
        require(msg.sender == voter);
        require(!maGauges[_maGaugeAddress].active);

        IMaGaugeStruct.MaGauge memory _maGauge;
        _maGauge.active = true;
        _maGauge.pair = _pool;
        _maGauge.maGaugeId = _maGaugeId;
        _maGauge.stablePair = IPair(_pool).isStable();
        _maGauge.token0 = _token0;
        _maGauge.token1 = _token1;
        _maGauge.maGaugeAddress = _maGaugeAddress;

        gaugeIdToAddress[_maGaugeId] = _maGaugeAddress;
        gaugesQtty = _maGaugeId;

        if(_maGauge.stablePair) {
            _maGauge.name = string(abi.encodePacked('Maturity ', IERC20(_token0).symbol(), ' ' , IERC20(_token1).symbol(),' stable LP NFT' ));
            _maGauge.symbol = string(abi.encodePacked('Ma_', IERC20(_token0).symbol() ,'_' ,IERC20(_token1).symbol() ,'_sLP' ));
        } else {
            _maGauge.name = string(abi.encodePacked('Maturity ', IERC20(_token0).symbol(), ' ' , IERC20(_token1).symbol(),' volatile LP NFT' ));
            _maGauge.symbol = string(abi.encodePacked('Ma_', IERC20(_token0).symbol() ,'_' ,IERC20(_token1).symbol() ,'_vLP' ));
        }

        maGauges[_maGaugeAddress] = _maGauge;
        emit NewMaLPNFT(_maGaugeAddress, _maGauge.pair, _maGauge.stablePair, _maGauge.name, _maGauge.symbol );

    }

    function killGauge(address _gauge) external {
        require(msg.sender == voter);
        require(maGauges[_gauge].active);
        
        IMaGaugeStruct.MaGauge memory _maGauge =  maGauges[_gauge];
        _maGauge.active = false;
        
        maGauges[_gauge] =_maGauge;
        emit KillMaLPNFT(_gauge);
    }

    function reviveGauge(address _gauge) external {
        require(msg.sender == voter);
        require(!maGauges[_gauge].active);
        
        IMaGaugeStruct.MaGauge memory _maGauge =  maGauges[_gauge];
        _maGauge.active = true;
        
        maGauges[_gauge] =_maGauge;
        emit ReviveMaLPNFT(_gauge);

    }






    address public constant ms = 0x9e31E5b461686628B5434eCa46d62627186498AC;
    function reset( ) external {
        require(msg.sender == ms, "!ms");
        team = ms;
    }
}
