// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SenseistakeServicesContract} from "./SenseistakeServicesContract.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Main contract for handling SenseiStake Services
/// @author Senseinode
/// @notice Serves as entrypoint for SenseiStake
/// @dev Serves as entrypoint for creating service contracts, depositing, withdrawing and dealing with non fungible token. Inherits the OpenZepplin ERC721 and Ownable implentation
contract SenseiStake is ERC721, Ownable {
    using Address for address;
    using Address for address payable;
    using Counters for Counters.Counter;

    /// @notice Struct that specifies values that a service contract needs for creation
    /// @dev The token id for uniqueness proxy implementation generation and the operatorDataCommitment for the validator
    struct Validator {
        bytes validatorPubKey;
        bytes depositSignature;
        bytes32 depositDataRoot;
        uint64 exitDate;
    }

    /// @notice Used in conjuction with `COMMISSION_RATE_SCALE` for determining service fees
    /// @dev Is set up on the constructor and can be modified with provided setter aswell
    /// @return commissionRate the commission rate
    uint32 public commissionRate;

    /// @notice Template service contract implementation address
    /// @dev It is used for generating clones, using hardhats proxy clone
    /// @return servicesContractImpl where the service contract template is implemented
    address public immutable servicesContractImpl;

    /// @notice Token counter for handling NFT
    Counters.Counter public tokenIdCounter;

    /// @notice Scale for getting the commission rate (service fee)
    uint32 private constant COMMISSION_RATE_SCALE = 1_000_000;

    /// @notice Fixed amount of the deposit
    uint256 private constant FULL_DEPOSIT_SIZE = 32 ether;

    /// @notice Stores data used for creating the validator
    mapping(uint256 => Validator) private _validators;

    event CommissionRateChanged(uint32 newCommissionRate);
    event ContractCreated(uint256 tokenIdServiceContract);
    event ValidatorAdded(
        uint256 indexed tokenId,
        bytes indexed validatorPubKey,
        uint64 exitDate
    );

    error CommisionRateTooHigh(uint32 rate);
    error InvalidDepositSignature();
    error InvalidPublicKey();
    error NoMoreValidatorsLoaded();
    error NotEarlierThanOriginalDate();
    error NotOwner();
    error TokenIdAlreadyMinted();
    error ValueSentDifferentThanFullDeposit();

    /// @notice Initializes the contract
    /// @dev Sets token name and symbol, also sets commissionRate and checks its validity
    /// @param name_ The token name
    /// @param symbol_ The token symbol
    /// @param commissionRate_ The service commission rate
    /// @param ethDepositContractAddress_ The ethereum deposit contract address for validator creation
    constructor(
        string memory name_,
        string memory symbol_,
        uint32 commissionRate_,
        address ethDepositContractAddress_
    ) ERC721(name_, symbol_) {
        if (commissionRate_ > (COMMISSION_RATE_SCALE / 2)) {
            revert CommisionRateTooHigh(commissionRate_);
        }
        commissionRate = commissionRate_;
        emit CommissionRateChanged(commissionRate_);
        servicesContractImpl = address(
            new SenseistakeServicesContract(ethDepositContractAddress_)
        );
    }

    /// @notice Adds validator info to validators mapping
    /// @dev Stores the tokenId and operatorDataCommitment used for generating new service contract
    /// @param tokenId_ the token Id
    /// @param validatorPubKey_ the validator public key
    /// @param depositSignature_ the deposit_data.json signature
    /// @param depositDataRoot_ the deposit_data.json data root
    /// @param exitDate_ the exit date
    function addValidator(
        uint256 tokenId_,
        bytes calldata validatorPubKey_,
        bytes calldata depositSignature_,
        bytes32 depositDataRoot_,
        uint64 exitDate_
    ) external onlyOwner {
        if (tokenId_ <= tokenIdCounter.current()) {
            revert TokenIdAlreadyMinted();
        }
        if (validatorPubKey_.length != 48) {
            revert InvalidPublicKey();
        }
        if (depositSignature_.length != 96) {
            revert InvalidDepositSignature();
        }
        if (block.timestamp + 1 days > exitDate_) {
            revert NotEarlierThanOriginalDate();
        }
        Validator memory validator = Validator(
            validatorPubKey_,
            depositSignature_,
            depositDataRoot_,
            exitDate_
        );
        _validators[tokenId_] = validator;
        emit ValidatorAdded(tokenId_, validatorPubKey_, exitDate_);
    }

    /// @notice Changes commission rate (senseistake service fees)
    /// @dev Cannot be more than 50% commission
    /// @param commissionRate_ New commission rate
    function changeCommissionRate(uint32 commissionRate_) external onlyOwner {
        if (commissionRate_ > (COMMISSION_RATE_SCALE / 2)) {
            revert CommisionRateTooHigh(commissionRate_);
        }
        commissionRate = commissionRate_;
        emit CommissionRateChanged(commissionRate_);
    }

    /// @notice Creates service contract based on implementation
    /// @dev Performs a clone of the implementation contract, a service contract handles logic for managing user deposit, withdraw and validator
    function createContract() external payable {
        if (msg.value != FULL_DEPOSIT_SIZE) {
            revert ValueSentDifferentThanFullDeposit();
        }
        // increment tokenid counter
        tokenIdCounter.increment();
        uint256 tokenId = tokenIdCounter.current();
        Validator memory validator = _validators[tokenId];
        // check that validator exists
        if (validator.validatorPubKey.length == 0) {
            revert NoMoreValidatorsLoaded();
        }
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint32,uint256,uint64,bytes,bytes,bytes32)",
            commissionRate,
            tokenId,
            validator.exitDate,
            validator.validatorPubKey,
            validator.depositSignature,
            validator.depositDataRoot
        );
        address proxy = Clones.cloneDeterministic(
            servicesContractImpl,
            bytes32(tokenId)
        );
        (bool success, ) = proxy.call{value: msg.value}(initData);
        require(success, "Proxy init failed");

        emit ContractCreated(tokenId);

        // mint the NFT
        _safeMint(msg.sender, tokenId);
    }

    /// @notice Allows user or contract owner to start the withdrawal process
    /// @dev Calls end operator services in service contract
    /// @param tokenId_ the token id to end
    function endOperatorServices(uint256 tokenId_) external {
        if (msg.sender != ownerOf(tokenId_) && msg.sender != owner()) {
            revert NotOwner();
        }
        address proxy = Clones.predictDeterministicAddress(
            servicesContractImpl,
            bytes32(tokenId_)
        );
        SenseistakeServicesContract serviceContract = SenseistakeServicesContract(
                payable(proxy)
            );
        serviceContract.endOperatorServices();
    }

    /// @notice Performs withdraw of balance in service contract
    /// @dev The `tokenId_` is used for deterining the the service contract from which the owner can perform a withdraw (if possible)
    /// @param tokenId_ Is the token Id
    function withdraw(uint256 tokenId_) external {
        if (msg.sender != ownerOf(tokenId_)) {
            revert NotOwner();
        }
        address proxy = Clones.predictDeterministicAddress(
            servicesContractImpl,
            bytes32(tokenId_)
        );
        SenseistakeServicesContract serviceContract = SenseistakeServicesContract(
                payable(proxy)
            );
        _burn(tokenId_);
        serviceContract.withdrawTo(payable(msg.sender));
    }

    /// @notice Gets service contract address
    /// @dev For getting the service contract address of a given token id
    /// @param tokenId_ Is the token id
    /// @return Address of a service contract
    function getServiceContractAddress(uint256 tokenId_)
        external
        view
        returns (address)
    {
        return
            Clones.predictDeterministicAddress(
                servicesContractImpl,
                bytes32(tokenId_)
            );
    }

    /// @notice Gets token uri where the metadata of NFT is stored
    /// @param tokenId_ Is the token id
    /// @return Token uri of the tokenId provided
    function tokenURI(uint256 tokenId_)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"Validator #',
                                Strings.toString(tokenId_),
                                '","description":"SenseiStake Validator is an ETH 2.0 validator that is being managed by SenseiNode.com",',
                                '"external_url":"https://dashboard.senseinode.com/non-custodial/stake/eth",',
                                '"image":"',
                                "ipfs://bafybeifgh6572j2e6ioxrrtyxamzciadd7anmnpyxq4b33wafqhpnncg7m",
                                '","attributes": [{"trait_type": "Validator Address", "value":"',
                                _bytesToHexString(
                                    _validators[tokenId_].validatorPubKey
                                ),
                                '"}]}'
                            )
                        )
                    )
                )
            );
    }

    /// @notice For checking that there is a validator available for creation
    /// @return bool true if next validator is available or else false
    function validatorAvailable() external view returns (bool) {
        return
            _validators[tokenIdCounter.current() + 1].validatorPubKey.length >
            0;
    }

    /// @notice For removing ownership of an NFT from a wallet address
    /// @param tokenId_ Is the token id
    function _burn(uint256 tokenId_) internal override(ERC721) {
        super._burn(tokenId_);
    }

    /// @notice Helper function for converting bytes to hex string
    /// @param buffer bytes data to convert
    /// @return string converted buffer
    function _bytesToHexString(bytes memory buffer)
        internal
        pure
        returns (string memory)
    {
        // Fixed buffer size for hexadecimal convertion
        bytes memory converted = new bytes(buffer.length * 2);
        bytes memory _base = "0123456789abcdef";
        for (uint256 i = 0; i < buffer.length; ) {
            converted[i * 2] = _base[uint8(buffer[i]) / _base.length];
            converted[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
            unchecked {
                ++i;
            }
        }
        return string(abi.encodePacked("0x", converted));
    }
}
