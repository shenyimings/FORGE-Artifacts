// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Strings.sol";

import "./utils/RocketStorageInterface.sol";
import "./utils/RocketNodeStakingInterface.sol";

/** 
    @title Rocketpool Staking Allocation Contract
    @author Blockscape Finance AG <info@blockscape.network>
    @notice collects staking, mints NFT in return for stake, which can be any amount of ETH
*/
contract BlockscapeETHStakeNFT is ERC1155Supply, ReentrancyGuard, Ownable {
    /// @dev RocketStorageInterface of rocketpool
    RocketStorageInterface constant rocketStorage =
        RocketStorageInterface(0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46);

    /// @notice Contract name
    string public constant name = "Blockscape ETH Stake NFTs";

    /// @notice Contract symbol
    string public constant symbol = "BSS";

    /// @notice Current inital Withdraw Fee
    uint256 initWithdrawFee = 20 * 1e18;

    /// @notice Current ETH pool supply
    uint256 poolSupply = 0;

    /// @notice Blockscape Rocket Pool Node Address
    address blockscapeRocketPoolNode =
        0xF6132f532ABc3902EA2DcaE7f8D7FCCdF7Ba4982;

    /**
        @notice state of the Solo Vault Pool
        @dev is `false` when pool is full, will be reopened, as soon as 
        the backend controller withdraws & transfers the stake
    */

    /** 
        @notice initial tokenID
        @dev the tokenID is used to identify the ETh Stake NFTs
    */
    uint256 tokenID = 1;

    /// @dev this is a given way to always retrieve the most up-to-date node address
    address rocketNodeStakingAddress =
        rocketStorage.getAddress(
            keccak256(abi.encodePacked("contract.address", "rocketNodeStaking"))
        );
    /// @dev rocketpool contract interface for interactions
    RocketNodeStakingInterface rocketNodeStaking =
        RocketNodeStakingInterface(rocketNodeStakingAddress);

    /// @dev Metadata struct
    struct Metadata {
        uint256 stakedETH;
        uint256 stakedTimestamp;
        bool institution;
        bytes32 institutionName;
        bool institutionVerified;
    }

    /// @dev Mappings of tokenID to Metadata
    mapping(uint256 => Metadata) tokenIDtoMetadata;
    /// @dev Mappings of tokenID to Validator
    mapping(uint256 => bytes) tokenIDtoValidator;

    /// @dev event for when a batch is tried to withdrawn but not enough rpl
    /// are available yet
    event RPLStakeRequired(uint256 _availRPL, uint256 _requiredRPL);

    /// @dev event for when a user requests a withdrawal
    event UserRequestedWithdrawal(
        uint256 _tokenID,
        address _user,
        uint256 _fee,
        uint256 _stakedETH
    );

    /// @dev event for when the RocketPool Node Address is changed
    event RocketPoolNodeAddressChanged(address _newAddress);

    /// @dev event for when the NFT stake is updated
    event StakeUpdated(uint256 _tokenID, address _owner, uint256 _newStake);

    /// @dev more RPL stake has to be done in order to open vault
    error NotEnoughRPLStake();

    /** 
        @notice each pool related vault gets its separate tokenID which depicts 
        the nft for each staker
        @dev the IPNS makes sure the nfts stay reachable via this link while 
        new nfts get added to the underlying ipfs folder
     */
    constructor()
        ERC1155("https://ipfs.blockscape.network/ipns/" "TBD/" "{id}.json")
    {}


    // functions

    // public & external functions

    /**
        @notice withdraw the given amount to the backend, triggered when the acciount balance is above 16 ETH or 8 ETH (RPIP-8)
        @dev the withdraw function remains public as safety measurement to
        not lock-in client stakes in case of contract issues
        @param _amount the amount in wei to withdraw
     */
    function withdraw(uint256 _amount) external onlyOwner {
        payable(owner()).transfer(_amount);
    }

    /// @notice used when staking eth into the contract
    /// @dev the vault must be open and equal the depositing amount
    function depositStakeNFT() external payable nonReentrant {
        assembly {
            // check is msg.value is higher than 0 ETH
            if lt(callvalue(), 0) {
                revert(0, 0)
            }
            if eq(callvalue(), 0) {
                revert(0, 0)
            }
        }

        // create metadata for the new tokenID
        _metadataStakeNFTInternal(msg.value, tokenID);

        assembly {
            // increase the tokenID
            let tokenID_value := sload(tokenID.slot)
            let new_tokenID_value := add(tokenID_value, 1)
            sstore(tokenID.slot, new_tokenID_value)
        }
        poolSupply += msg.value;
    }

    /**
        @notice update the stake of the given tokenID, if the NFT owner decides to stake more ETH
        @dev emits the StakeUpdated event & increases the poolSupply based on the msg.value
        @param _tokenID Identifier of the vault
    */
    function updateStake(uint256 _tokenID) external payable nonReentrant {
        if (balanceOf(msg.sender, _tokenID) >= 1) {
            assembly {
                // check is msg.value is higher than 0 ETH
                if lt(callvalue(), 0) {
                    revert(0, 0)
                }
                if eq(callvalue(), 0) {
                    revert(0, 0)
                }
            }

            // update ETH value of the tokenID by adding the msg.value
            tokenIDtoMetadata[_tokenID].stakedETH += msg.value;

            poolSupply += msg.value;

            // emit event
            emit StakeUpdated(
                _tokenID,
                msg.sender,
                tokenIDtoMetadata[_tokenID].stakedETH
            );
        } else {
            revert("You do not own this NFT");
        }
    }

    /**
        @notice used when user wants to unstake
        @param _tokenID is the tokenID of the NFT
        @return _amount how much the user gets back
     */

    function userRequestFullWithdraw(uint256 _tokenID)
        external
        returns (uint256 _amount)
    {
        uint256 curWithdrawFee = viewuserRequestFullWithdraw(_tokenID);

         if (balanceOf(msg.sender, _tokenID) >= 1) {
        poolSupply -= tokenIDtoMetadata[_tokenID].stakedETH;

        emit UserRequestedWithdrawal(
            _tokenID,
            msg.sender,
            curWithdrawFee,
            tokenIDtoMetadata[_tokenID].stakedETH
        );

         }

        return curWithdrawFee;
    }

    // functions for future maintainability

    /**
        @notice the withdraw fee might be changed in the future
        @param _amount the new fee in wei
     */
    function setWithdrawFee(uint256 _amount) external onlyOwner {
        initWithdrawFee = _amount;
    }

    /**
        @notice gets used if rocket pool changes the address of their node
        @param _newBlockscapeRocketPoolNode the new address of the pool node
     */
    function setBlockscapeRocketPoolNode(address _newBlockscapeRocketPoolNode)
        external
        onlyOwner
    {
        blockscapeRocketPoolNode = _newBlockscapeRocketPoolNode;
        emit RocketPoolNodeAddressChanged(_newBlockscapeRocketPoolNode);
    }

    // view / pure functions

    /**
        @notice show the currently available RPL stake which is needed to create 
        a pool on rocketscape
        @return the current available RPL stake with already deducted minimum
        stake
     */
    function getAvailableRPLStake() public view returns (uint256) {
        uint256 nodeRPLStake = rocketNodeStaking.getNodeRPLStake(
            blockscapeRocketPoolNode
        );

        return nodeRPLStake;
    }

    /**
        @notice calculates the required RPL needed to stake according to 
        poolsize
        @dev if the minipoollimit is `0` then the required stake is also `0`!
        @return the RPLs needed
     */
    function getReqRPLStake() public view returns (uint256) {
        uint256 minipoolLimit = rocketNodeStaking.getNodeMinipoolLimit(
            blockscapeRocketPoolNode
        );

        uint256 minimumRPLStake = rocketNodeStaking.getNodeMinimumRPLStake(
            blockscapeRocketPoolNode
        );

        if (minipoolLimit == 0) {
            return 0;
        }

        return (minimumRPLStake / minipoolLimit);
    }

    /// @notice has the node enough RPL to stake another minipool
    function hasNodeEnoughRPLStake() public view returns (bool) {
        uint256 minipoolLimit = rocketNodeStaking.getNodeMinipoolLimit(
            blockscapeRocketPoolNode
        );
        if (minipoolLimit == 0) {
            return false;
        }

        uint256 nodeRPLStake = rocketNodeStaking.getNodeRPLStake(
            blockscapeRocketPoolNode
        );
        uint256 minimumReqRPL = getReqRPLStake();

        return (nodeRPLStake - minimumReqRPL) >= 0;
    }

    /**
     * @notice returns the current ETH supply of the pool(s)
     *
     */
    function getPoolSupply() public view returns (uint256) {
        return poolSupply;
    }

    /**
        @notice how much fees would the user has to pay if he would unstake now
        within the first year of staking the fee is starting at 20% & decreasing linearly, afterwards 0.5%
        @param _tokenID which pool the staker wants to unstake
        @return _amount how much the user would pay on fees
     */
    function viewuserRequestFullWithdraw(uint256 _tokenID)
        public
        view
        returns (uint256 _amount)
    {
        uint256 curWithdrawFee = initWithdrawFee;

        if (balanceOf(msg.sender, _tokenID) >= 1) {
            uint256 secFee = (initWithdrawFee / 365 days); // 20%
            uint256 timePassed = block.timestamp -
                (tokenIDtoMetadata[_tokenID].stakedTimestamp);

            uint256 maxTime05EthReached = 30747600;

            if (timePassed >= maxTime05EthReached) {
                curWithdrawFee = 5 * 1e17; // fixed minimum fee 0,5 ether
            } else {
                curWithdrawFee = (initWithdrawFee - (secFee * timePassed));
            }
        }
        return curWithdrawFee;
    }

    /**
        @notice gets the metadata of a given pool
        @param _tokenID identifies the pool
        @return Metadata of the pool 
        @return the validator address
     */
    function getMetadata(uint256 _tokenID)
        external
        view
        returns (Metadata memory, bytes memory)
    {
        return (tokenIDtoMetadata[_tokenID], tokenIDtoValidator[_tokenID]);
    }

    /**
        @notice the tokenID is incremented with every pool
        @return the current tokenID 
     */
    function getTokenID() public view returns (uint256) {
        return tokenID;
    }

    /**
        @notice how much balance does this vault current have
        @return amount in wei
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice how many staker are there totally
    /// @return total amount of staker
    function totalSupply() external view returns (uint256) {
        uint256 amount = 0;
        for (uint256 i = 1; i <= this.getTokenID(); i++) {
            amount += this.totalSupply(i);
        }
        return amount;
    }

    /** 
        @notice stake nft metdata location
        @dev this path will never change as the contract defines a collection
        @return the fixed collection metadata path 
     */
    function contractURI() external pure returns (string memory) {
        return "https://ipfs.blockscape.network/ipfs/TBD";
    }

    /**
        @notice gets the url to the metadata of a given pool
        @param _tokenID the pool
        @return the url
     */
    function uri(uint256 _tokenID)
        public
        pure
        override
        returns (string memory)
    {
        return
            string.concat(
                "https://ipfs.blockscape.network/ipns/TBD/",
                Strings.toString(_tokenID),
                ".json"
            );
    }

    // internal functions

    /**
        @notice creates and mints metadata for a given NFT tokenID
        @param _stakedETH staked amount from the sender
        @param _tokenID Identifier of the vault
    */
    function _metadataStakeNFTInternal(uint256 _stakedETH, uint256 _tokenID)
        internal
    {
        Metadata memory metadata;

        metadata.stakedETH = _stakedETH;
        metadata.stakedTimestamp = block.timestamp;

        tokenIDtoMetadata[_tokenID] = metadata;
        tokenIDtoValidator[_tokenID] = "";

        _mint(msg.sender, _tokenID, 1, "");
    }

    /**
        @notice compares two values and checks if there are equal
        @dev hashes the stringified values and compares those hashes
        @return are the bytes equal
     */
    function _compareBytes(bytes memory a, bytes memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
