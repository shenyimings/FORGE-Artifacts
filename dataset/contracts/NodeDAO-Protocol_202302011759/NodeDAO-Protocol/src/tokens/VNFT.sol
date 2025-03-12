// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "ERC721A-Upgradeable/ERC721AUpgradeable.sol";
import "ERC721A-Upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import "src/interfaces/ILiquidStaking.sol";

contract VNFT is
    Initializable,
    OwnableUpgradeable,
    ERC721AQueryableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    address public liquidStakingContract;

    uint256 public constant MAX_SUPPLY = 6942069420;

    struct Validator {
        uint256 operatorId;
        uint256 initHeight;
        bytes pubkey;
    }

    mapping(bytes => uint256) public validatorRecords; // key is pubkey, value is operator_id
    mapping(uint256 => uint256) public operatorRecords; // key is operator_id, value is  token counts
    mapping(uint256 => uint256[]) public operatorEmptyNfts;
    mapping(uint256 => uint256) public operatorEmptyNftIndex;

    Validator[] public validators;
    mapping(uint256 => address) public lastOwners;

    event BaseURIChanged(string _before, string _after);
    event Transferred(address _to, uint256 _amount);
    event LiquidStakingChanged(address _before, address _after);
    event OpenSeaState(bool _isActive);

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize() public initializer initializerERC721A {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __ERC721A_init("Validator NFT", "vNFT");
    }

    modifier onlyLiquidStaking() {
        require(liquidStakingContract == msg.sender, "Not allowed to mint/burn nft");
        _;
    }

    /**
     * @notice Returns the validators that are active (may contain validator that are yet active on beacon chain)
     */
    function activeValidators() external view returns (bytes[] memory) {
        uint256 total = _nextTokenId();
        uint256 tokenIdsIdx;
        bytes[] memory _validators = new bytes[](total);
        TokenOwnership memory ownership;

        for (uint256 i = _startTokenId(); i < total; ++i) {
            ownership = _ownershipAt(i);
            if (ownership.burned) {
                continue;
            }

            _validators[tokenIdsIdx++] = validators[i].pubkey;
        }

        return _validators;
    }

    /**
     * @notice Returns the tokenId that are active (may contain validator that are yet active on beacon chain)
     */
    function activeNfts() external view returns (uint256[] memory) {
        uint256 total = _nextTokenId();
        uint256 tokenIdsIdx;
        uint256[] memory _nfts = new uint256[](total);
        TokenOwnership memory ownership;

        for (uint256 i = _startTokenId(); i < total; ++i) {
            ownership = _ownershipAt(i);
            if (ownership.burned) {
                continue;
            }

            _nfts[tokenIdsIdx++] = i;
        }

        return _nfts;
    }

    /**
     * @notice Checks if a validator exists
     * @param pubkey - A 48 bytes representing the validator's public key
     */
    function validatorExists(bytes calldata pubkey) external view returns (bool) {
        return validatorRecords[pubkey] != 0;
    }

    /**
     * @notice Finds the validator's public key of a nft
     * @param tokenId - tokenId of the validator nft
     */
    function validatorOf(uint256 tokenId) external view returns (bytes memory) {
        return validators[tokenId].pubkey;
    }

    /**
     * @notice Finds the operator id of a nft
     * @param tokenId - tokenId of the validator nft
     */
    function operatorOf(uint256 tokenId) external view returns (uint256) {
        return validators[tokenId].operatorId;
    }

    /**
     * @notice Finds all the validator's public key of a particular address
     * @param owner - The particular address
     */
    function validatorsOfOwner(address owner) public view returns (bytes[] memory) {
        unchecked {
            //slither-disable-next-line uninitialized-local
            uint256 tokenIdsIdx;
            //slither-disable-next-line uninitialized-local
            address currOwnershipAddr;
            uint256 tokenIdsLength = balanceOf(owner);
            bytes[] memory pubkeys = new bytes[](tokenIdsLength);
            TokenOwnership memory ownership;
            for (uint256 i = 0; tokenIdsIdx != tokenIdsLength; ++i) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == owner) {
                    pubkeys[tokenIdsIdx++] = validators[i].pubkey;
                }
            }
            return pubkeys;
        }
    }

    /**
     * @notice Finds the tokenId of a validator
     * @dev Returns MAX_SUPPLY if not found
     * @param pubkey - A 48 bytes representing the validator's public key
     */
    function tokenOfValidator(bytes calldata pubkey) external view returns (uint256) {
        require(pubkey.length != 0, "Invalid pubkey");
        for (uint256 i = 0; i < validators.length; i++) {
            if (keccak256(validators[i].pubkey) == keccak256(pubkey) && _exists(i)) {
                return i;
            }
        }
        return MAX_SUPPLY;
    }

    /**
     * @notice Finds all the validator's public key of a particular operator
     * @param operatorId - The particular address of the operator
     */
    function validatorsOfOperator(uint256 operatorId) external view returns (bytes[] memory) {
        uint256 total = _nextTokenId();
        uint256 tokenIdsIdx;
        bytes[] memory _validators = new bytes[](total);
        TokenOwnership memory ownership;

        for (uint256 i = _startTokenId(); i < total; ++i) {
            ownership = _ownershipAt(i);
            if (ownership.burned) {
                continue;
            }
            if (validatorRecords[validators[i].pubkey] == operatorId) {
                _validators[tokenIdsIdx++] = validators[i].pubkey;
            }
        }

        return _validators;
    }

    /**
     * @notice Returns the init height of the tokenId
     * @param tokenId - tokenId of the validator nft
     */
    function initHeightOf(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");

        return validators[tokenId].initHeight;
    }

    /**
     * @notice Returns the last owner before the nft is burned
     * @param tokenId - tokenId of the validator nft
     */
    function lastOwnerOf(uint256 tokenId) external view returns (address) {
        require(_ownershipAt(tokenId).burned, "Token not burned yet");

        return lastOwners[tokenId];
    }

    function getNextTokenId() external view returns (uint256) {
        return _nextTokenId();
    }

    /**
     * @notice Mints a Validator nft (vNFT)
     * @param _pubkey -  A 48 bytes representing the validator's public key
     * @param _to - The recipient of the nft
     * @param _operatorId - The operator repsonsible for operating the physical node
     */
    function whiteListMint(bytes calldata _pubkey, address _to, uint256 _operatorId)
        external
        onlyLiquidStaking
        returns (bool, uint256)
    {
        require(totalSupply() + 1 <= MAX_SUPPLY, "Exceed MAX_SUPPLY");

        uint256 nextTokenId = _nextTokenId();
        if (_pubkey.length == 0) {
            operatorEmptyNfts[_operatorId].push(nextTokenId);
        } else {
            require(validatorRecords[_pubkey] == 0, "Pub key already in used");
            validatorRecords[_pubkey] = _operatorId;

            if (operatorEmptyNfts[_operatorId].length != operatorEmptyNftIndex[_operatorId]) {
                uint256 tokenId = operatorEmptyNfts[_operatorId][operatorEmptyNftIndex[_operatorId]];
                operatorEmptyNftIndex[_operatorId] += 1;
                validators[tokenId].pubkey = _pubkey;
                return (false, tokenId);
            }
        }

        validators.push(Validator({operatorId: _operatorId, initHeight: block.number, pubkey: _pubkey}));
        operatorRecords[_operatorId] += 1;

        _safeMint(_to, 1);
        return (true, nextTokenId);
    }

    /**
     * @notice Burns a Validator nft (vNFT)
     * @param tokenId - tokenId of the validator nft
     */
    function whiteListBurn(uint256 tokenId) external onlyLiquidStaking {
        lastOwners[tokenId] = ownerOf(tokenId);
        _burn(tokenId);

        operatorRecords[validators[tokenId].operatorId] -= 1;
    }

    /**
     * @notice Get the number of operator's nft
     * @param operatorId - operator id
     */
    function getNftCountsOfOperator(uint256 operatorId) external view returns (uint256) {
        return operatorRecords[operatorId];
    }

    // // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        emit BaseURIChanged(_baseTokenURI, baseURI);
        _baseTokenURI = baseURI;
    }

    /**
     * @notice set LiquidStaking contract address
     * @param _liqStakingAddress - contract address
     */
    function setLiquidStaking(address _liqStakingAddress) external onlyOwner {
        require(_liqStakingAddress != address(0), "LiquidStaking address provided invalid");
        emit LiquidStakingChanged(liquidStakingContract, _liqStakingAddress);
        liquidStakingContract = _liqStakingAddress;
    }

    function numberMinted(address owner) external view returns (uint256) {
        return _numberMinted(owner);
    }

    ////////below is the new code//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function isApprovedForAll(address owner, address operator)
        public
        view
        override (ERC721AUpgradeable, IERC721AUpgradeable)
        returns (bool)
    {
        // Get a reference to OpenSea's proxy registry contract by instantiating
        // the contract using the already existing address.

        if (operator == liquidStakingContract) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }
}
