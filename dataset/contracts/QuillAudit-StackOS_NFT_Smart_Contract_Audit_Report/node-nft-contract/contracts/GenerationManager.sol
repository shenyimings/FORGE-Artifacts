//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IStackOsNFT.sol";
import "./StackOsNFTBasic.sol";

contract GenerationManager is Ownable, ReentrancyGuard {
    using Strings for uint256;

    address stableAcceptor;
    address exchange;
    address dao;
    address distr;

    IStackOsNFT[] private generations;
    mapping(address => uint256) private ids;

    struct Deployment {
        string name;
        string symbol;
        address stackToken;
        address darkMatter;
        address subscription;
        address sub0;
        uint256 participationFee;
        uint256 subsFee;
        uint256 daoFee;
        uint256 distrFee;
        uint256 maxSupplyGrowthPercent;
        uint256 transferDiscount;
        uint256 timeLock;
        address royaltyAddress;
        address market;
    }
    Deployment deployment;

    modifier onlyOwnerOrStackContract() {
        require(owner() == _msgSender() || isAdded(_msgSender()), "Caller is not the owner or stack contract");
        _;
    }

    constructor() {}

    function adjustAddressSettings(
        address _stableAcceptor,
        address _exchange,
        address _dao,
        address _distr
    )
        public
        onlyOwner
    {
        stableAcceptor = _stableAcceptor;
        exchange = _exchange;
        dao = _dao;
        distr = _distr;
    }

    /*
     * @title Save settings for auto deployment.
     * @param _maxSupplyGrowthPercent increase max supply for new contract by this percent.
     * @dev Could only be invoked by the contract owner.
     */
    function setupDeploy(
        string memory _name,
        string memory _symbol,
        address _stackToken,
        address _darkMatter,
        address _subscription,
        address _sub0,
        uint256 _participationFee,
        uint256 _subsFee,
        uint256 _maxSupplyGrowthPercent,
        uint256 _transferDiscount,
        uint256 _timeLock,
        address _royaltyAddress
    ) public onlyOwner {
        require(_maxSupplyGrowthPercent <= 10000, "invalid basis points");
        deployment.name = _name;
        deployment.symbol = _symbol;
        deployment.stackToken = _stackToken;
        deployment.darkMatter = _darkMatter;
        deployment.subscription = _subscription;
        deployment.sub0 = _sub0;
        deployment.participationFee = _participationFee;
        deployment.subsFee = _subsFee;
        deployment.maxSupplyGrowthPercent = _maxSupplyGrowthPercent;
        deployment.transferDiscount = _transferDiscount;
        deployment.timeLock = _timeLock;
        deployment.royaltyAddress = _royaltyAddress;
    }

    /*
     * @title Save additional settings for auto deployment.
     * @param Address of market.
     * @dev Could only be invoked by the contract owner.
     * @dev Must be called along with first setup function.
     */
    function setupDeploy2(
        address _market,
        uint256 _daoFee,
        uint256 _distrFee
    ) public onlyOwner {
        deployment.market = _market;
        deployment.daoFee = _daoFee;
        deployment.distrFee = _distrFee;
    }

    /*
     * @title Called by StackNFTBasic once it reaches max supply.
     * @dev Could only be invoked by the last StackOsNFTBasic generation.
     * @dev Generation id is appended to the name. 
     */
    function deployNextGenPreset() public returns (IStackOsNFTBasic) 
    {
        // Can only be called from StackNFT contracts
        uint256 callerGenerationId = getIDByAddress(msg.sender);
        // Cannot deploy next generation if it's already exists
        require(callerGenerationId == generations.length - 1, 
            "Next generation already deployed"
        );

        IStackOsNFT caller = get(callerGenerationId);
        uint256 maxSupply = caller.getMaxSupply() * 
            (deployment.maxSupplyGrowthPercent + 10000) / 10000;
        string memory name = string(abi.encodePacked(
            deployment.name,
            " ",
            uint256(count() + 1).toString()
        ));
        StackOsNFTBasic stack = StackOsNFTBasic(
            address(
                new StackOsNFTBasic()
            )
        );
        stack.setName(name);
        stack.setSymbol(deployment.symbol);
        stack.initialize(
            deployment.stackToken,
            deployment.darkMatter,
            deployment.subscription,
            deployment.sub0,
            deployment.royaltyAddress,
            stableAcceptor,
            exchange,
            deployment.participationFee,
            maxSupply,
            deployment.transferDiscount,
            deployment.timeLock
        );
        add(IStackOsNFT(address(stack)));
        stack.setFees(deployment.subsFee, deployment.daoFee, deployment.distrFee);
        stack.adjustAddressSettings(dao, distr);
        stack.whitelist(address(deployment.darkMatter));
        stack.whitelist(address(deployment.market));
        stack.transferOwnership(Ownable(msg.sender).owner());
        return IStackOsNFTBasic(address(stack));
    }

    /*
     * @title Add next generation of StackNFT.
     * @param IStackOsNFT address.
     * @dev Could only be invoked by the contract owner or StackNFT contract.
     * @dev Address should be unique.
     */
    function add(IStackOsNFT _stackOS) public onlyOwnerOrStackContract {
        require(address(_stackOS) != address(0), "Must be not zero-address");
        for (uint256 i; i < generations.length; i++) {
            require(generations[i] != _stackOS, "Address already added");
        }
        ids[address(_stackOS)] = generations.length;
        generations.push(_stackOS);
    }

    /*
     * @title Deploy new StackOsNFTBasic manually.
     * @dev Additional setup is required after deploy: 
     * @dev Whitelist DarkMatter and Market.
     * @dev Call to setFees.
     * @dev Adjust address settings.
     * @dev Example of full setup can be seen in deployNextGenPreset.
     */

    function deployNextGen(
        string memory _name,
        string memory _symbol,
        address _stackToken,
        address _darkMatter,
        address _subscription,
        address _sub0,
        uint256 _participationFee,
        uint256 _maxSupply,
        uint256 _transferDiscount,
        uint256 _timeLock,
        address _royaltyAddress
    ) public onlyOwner returns (IStackOsNFTBasic) {
        StackOsNFTBasic stack = StackOsNFTBasic(
            address(
                new StackOsNFTBasic()
            )
        );
        stack.setName(_name);
        stack.setSymbol(_symbol);
        stack.initialize(
            _stackToken,
            _darkMatter,
            _subscription,
            _sub0,
            _royaltyAddress,
            stableAcceptor,
            exchange,
            _participationFee,
            _maxSupply,
            _transferDiscount,
            _timeLock
        );
        add(IStackOsNFT(address(stack)));
        stack.transferOwnership(msg.sender);
        return IStackOsNFTBasic(address(stack));
    }

    /*
     * @title Get total number of generations added.
     */
    function count() public view returns (uint256) {
        return generations.length;
    }

    /*
     * @title Get generation of StackNFT contract by id.
     * @param Generation id.
     * @dev Must be valid generation id to avoid out-of-bounds error.
     */
    function get(uint256 generationId) public view returns (IStackOsNFT) {
        return generations[generationId];
    }

    /*
     * @title Get generation ID by address.
     * @param Stack NFT contract address
     */
    function getIDByAddress(address _nftAddress) public view returns (uint256) {
        uint256 generationID = ids[_nftAddress];
        if (generationID == 0) {
            require(address(get(0)) == _nftAddress, "Not Correct Address");
        }
        return generationID;
    }

    /*
     * @title Returns whether StackNFT contract is added to this manager.
     * @param Stack NFT contract address
     */
    function isAdded(address _nftAddress) public view returns (bool) {
        uint256 generationID = ids[_nftAddress];
        return generations.length > generationID && address(get(generationID)) == _nftAddress;
    }
}
