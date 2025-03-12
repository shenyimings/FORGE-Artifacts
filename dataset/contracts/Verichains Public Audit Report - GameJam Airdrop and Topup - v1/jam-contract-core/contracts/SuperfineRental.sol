// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRentalContract.sol";
import "./utils/HasNoEther.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IOracle.sol";

contract SuperfineRental is IRentalContract, HasNoEther, ReentrancyGuard {
    address private backendAddr;

    address private oracleContract;

    // Cut owner takes on each auction, measured in basis points (1/100 of a percent).
    // Values 0-10,000 map to 0%-100%
    uint256 public ownerCut;

    uint256 public slippageTolerance; // slippageTolerance 0 -> 10000 mean 0% to 100%

    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        private rentPriceUSD; // pricing Of NFT in USDT (with decimals 6)

    mapping(string => uint256) private receiptLog;
    mapping(address => uint256) private ownerProfit;
    mapping(address => mapping(string => uint256)) private rentedExpire;

    constructor(address _newOwner) {
        transferOwnership(_newOwner);
        backendAddr = _newOwner;
    }

    fallback() external payable {}

    receive() external payable {}

    /* ======== Config SuperfineRental ======== */

    function setOwnerCut(uint256 _ownerCut) external onlyOwner {
        require(
            _ownerCut <= 10000,
            "SuperfineRental: owner cut cannot exceed 100%"
        );
        ownerCut = _ownerCut;
    }

    function setBackendAddress(address _backendAddr) external onlyOwner {
        backendAddr = _backendAddr;
    }

    function setOracleContract(address _oracleContract) external onlyOwner {
        oracleContract = _oracleContract;
    }

    function setSlippageTolerance(
        uint256 _slippageTolerance
    ) external onlyOwner {
        slippageTolerance = _slippageTolerance;
    }

    /* ======== End Config SuperfineRental ======== */

    /* ======== Internal function ======== */

    function _getERC20Contract(
        address _erc20Address
    ) internal pure returns (IERC20) {
        IERC20 candidateContract = IERC20(_erc20Address);
        return candidateContract;
    }

    function _getOracleContract() internal view returns (IOracle) {
        IOracle candidateContract = IOracle(oracleContract);
        return candidateContract;
    }

    function _updateExpire(
        address renter,
        uint256 chainId,
        address contractAddress,
        uint256 tokenId,
        uint8 rentedDay
    ) internal nonReentrant {
        string memory key = string(
            abi.encodePacked(
                Strings.toString(chainId),
                "-",
                abi.encodePacked(contractAddress),
                "-",
                Strings.toString(tokenId)
            )
        );
        uint256 currentTime = block.timestamp;
        if (currentTime > rentedExpire[renter][key]) {
            rentedExpire[renter][key] = currentTime + (rentedDay * 1 days);
        } else {
            rentedExpire[renter][key] =
                rentedExpire[renter][key] +
                (rentedDay * 1 days);
        }
    }

    /* ======== End Internal function ======== */

    /* ======== Business function ======== */

    /**
     * @dev update RentNFT pricing, 0 mean not public for rent
     */
    function updateRentPrice(
        uint256 chainId,
        address contractAddress,
        uint256 tokenId,
        uint256 pricingPerDay
    ) external override onlyBackend returns (bool) {
        rentPriceUSD[chainId][contractAddress][tokenId] = pricingPerDay;
        // Emit event UpdateRentPrice
        emit UpdateRentPrice(chainId, contractAddress, tokenId, pricingPerDay);
        return true;
    }

    /**
     * @dev add profit to user. USDT alway have 6 decimal
     * TODO: Need oracle to convert usdt to jam
     */
    function addProfit(
        address owner,
        uint256 addingBalance,
        string memory receiptId
    ) public override onlyNewReceiptId(receiptId) onlyBackend returns (bool) {
        // TODO: need convert addingBalance from usdt to jam
        IOracle or = _getOracleContract();
        uint256 jamRate = or.GetRate(address(0));
        // calculate the jamBalance
        uint256 jamBalance = jamRate * addingBalance;
        ownerProfit[owner] = ownerProfit[owner] + jamBalance;
        receiptLog[receiptId] = jamBalance;
        return true;
    }

    /**
     * @dev rent the NFT
     * TODO : need oracle to continue
     */
    function rentNFT(
        uint256 chainId,
        address contractAddress,
        uint256 tokenId,
        uint8 rentedDay,
        address paidToken,
        uint256 amount
    ) external payable override returns (bool) {
        if (paidToken == address(0)) {
            require(msg.value >= amount, "SuperfineRental: not enough balance");
        }
        IOracle or = _getOracleContract();
        uint256 tokenRate = or.GetRate(paidToken);
        require(tokenRate > 0, "SuperfineRental: paid token is not support");
        uint256 totalBalanceUSD = amount / tokenRate;
        uint256 pricingPerDayUSD = viewNFTPricing(
            chainId,
            contractAddress,
            tokenId
        );
        require(
            pricingPerDayUSD > 0,
            "SuperfineRental: nft is not public for rent"
        );
        //check slippageTolerance
        uint256 billAmount = pricingPerDayUSD * rentedDay;
        require(
            totalBalanceUSD * 10000 >= billAmount * (10000 - slippageTolerance),
            "SuperfineRental: out of slippage tolerance"
        );
        if (paidToken != address(0)) {
            // Transfer ERC20
            SafeERC20.safeTransferFrom(
                IERC20(paidToken),
                msg.sender,
                address(this),
                amount
            );
        }

        // calculate fee and addingBalance
        uint256 fee = uint256(totalBalanceUSD * ownerCut) / uint256(10000);
        totalBalanceUSD = totalBalanceUSD - fee;
        emit RentNFT(
            msg.sender,
            chainId,
            contractAddress,
            tokenId,
            rentedDay,
            paidToken,
            amount,
            totalBalanceUSD,
            fee
        );
        return true;
    }

    /**
     * @dev rent the NFT via IAP
     * TODO : need oracle to continue
     */
    function rentNFTViaIAP(
        uint256 chainId,
        address contractAddress,
        uint256 tokenId,
        address renter,
        address owner,
        uint8 rentedDay,
        uint256 addingBalance,
        string memory receiptId
    ) external override onlyBackend returns (bool) {
        // TODO: need oracle to convert addingBalance form USDT to JAM
        addProfit(owner, addingBalance, receiptId);
        emit RentNFTViaIAP(
            renter,
            owner,
            chainId,
            contractAddress,
            tokenId,
            rentedDay,
            receiptId,
            addingBalance
        );
        return true;
    }

    /* ======== End Business function ======== */

    /* ======== Query function ======== */

    function viewProfit() public view returns (uint256) {
        return ownerProfit[msg.sender];
    }

    function viewNFTExpire(
        uint256 chainId,
        address contractAddress,
        uint256 tokenId
    ) public view returns (uint256) {
        string memory key = string(
            abi.encodePacked(
                Strings.toString(chainId),
                "-",
                abi.encodePacked(contractAddress),
                "-",
                Strings.toString(tokenId)
            )
        );
        return rentedExpire[msg.sender][key];
    }

    function viewNFTPricing(
        uint256 chainId,
        address contractAddress,
        uint256 tokenId
    ) public view returns (uint256) {
        return rentPriceUSD[chainId][contractAddress][tokenId];
    }

    function viewBillAmountOnUSD(
        uint256 chainId,
        address contractAddress,
        uint256 tokenId,
        uint8 rentedDay
    ) public view returns (uint256) {
        uint256 pricingPerDayUSD = viewNFTPricing(
            chainId,
            contractAddress,
            tokenId
        );
        require(
            pricingPerDayUSD > 0,
            "SuperfineRental: nft is not public for rent"
        );

        //check slippageTolerance
        uint256 billAmount = pricingPerDayUSD * rentedDay;
        return billAmount;
    }

    function viewBillAmountOnToken(
        uint256 chainId,
        address contractAddress,
        uint256 tokenId,
        uint8 rentedDay,
        address paidToken
    ) public view returns (uint256) {
        uint256 billAmount = viewBillAmountOnUSD(
            chainId,
            contractAddress,
            tokenId,
            rentedDay
        );
        IOracle or = _getOracleContract();
        uint256 tokenRate = or.GetRate(paidToken);
        billAmount = billAmount * tokenRate;
        return billAmount;
    }

    /* ======== End Query function ======== */

    /* ======== Admin Withdraw ERC20 ======== */
    function reclaimERC20(address _erc20Address) external onlyOwner {
        IERC20 erc20Contract = _getERC20Contract(_erc20Address);
        erc20Contract.transfer(owner(), erc20Contract.balanceOf(address(this)));
    }

    /* ======== User Query function ======== */
    function reclaimProfit() external {
        uint256 amount = ownerProfit[msg.sender];
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        ownerProfit[msg.sender] = ownerProfit[msg.sender] - amount;
        require(success, "SuperfineRental: transfer failed.");
    }

    /* ======== End User Query function ======== */

    /* ======== Modfier ========= */
    modifier onlyBackend() {
        require(
            backendAddr == msg.sender,
            "SuperfineRental: only backend call"
        );
        _;
    }

    modifier onlyNewReceiptId(string memory receiptId) {
        require(
            receiptLog[receiptId] == 0,
            "SuperfineRental: only new receiptId accepted"
        );
        _;
    }
}
