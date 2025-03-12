pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../utils/TieredOwnable.sol";
import "../interfaces/ISkyweaverAssets.sol";
import "@0xsequence/erc-1155/contracts/utils/SafeMath.sol"; 
import "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC20.sol";
import "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

/**
 * @notice Allows players mint items in exchange for burning items and some USDC
 *         Minting logic supports bonding curve for USDC.
 */
contract BondingCurveFactory is IERC1155TokenReceiver, TieredOwnable {
  using SafeMath for uint256;
  
  /***********************************|
  |             Variables             |
  |__________________________________*/

  // Assets
  IERC20 immutable public usdc;                      // USDC contract address
  ISkyweaverAssets immutable public skyweaverAssets; // ERC-1155 Skyweaver items contract
  uint256  immutable internal itemRangeMin;          // Lower bound for the range of items IDs that can be used to mint
  uint256 immutable internal itemRangeMax;           // Upper bound for the range of items IDs that can be used to mint

  // Amount of items needed to be burnt per mint
  uint256 internal immutable COST_IN_ITEMS;

  // Minting curve parameters
  // Curve is (x + USDC_CURVE_CONSTANT)^2 / USDC_CURVE_SCALE_DOWN
  uint256 internal immutable USDC_CURVE_CONSTANT;   // Starting X value on the curve
  uint256 internal immutable USDC_CURVE_SCALE_DOWN; // Multiplier we use as denominator for the curve
  uint256 internal immutable USDC_CURVE_TICK_SIZE;  // Supply amount after which price increases

  // Mapping for tracking supplies
  mapping (uint256 => uint256) public mintedAmounts; // Tracks number of items minted by this contract

  // Payment payload on erc-1155 transfer
  struct MintTokenRequest {
    address recipient;            // Who receives the tokens
    uint256[] itemsBoughtIDs;     // Token IDs to buy
    uint256[] itemsBoughtAmounts; // Amount of token to buy for each ID
    uint256 maxUSDC;              // Maximum amount of USDC to use for the order
  }

  /***********************************|
  |            Constructor            |
  |__________________________________*/

  /**
   * @notice Create factory, link skyweaver items and store initial parameters
   * @param _firstOwner             Address of the first owner
   * @param _usdc                   The address of the USDC contract
   * @param _skyweaverAssetsAddress The address of the Skyweaver ERC-1155 contract
   * @param _itemRangeMin           Minimum id for silver cards
   * @param _itemRangeMax           Maximum id for silver cards
   * @param _costInItems            Amount of items needed to burn per mint
   * @param _usdcCurveConstant      Starting X value on the curve
   * @param _usdcCurveScaleDown     Multiplier we use as denominator for the curve
   * @param _usdcCurveTickSize      Supply amount after which price increases
   */
  constructor(
    address _firstOwner,
    uint256 _usdc,
    address _skyweaverAssetsAddress,
    uint256 _itemRangeMin,
    uint256 _itemRangeMax,
    uint256 _costInItems,
    uint256 _usdcCurveConstant,
    uint256 _usdcCurveScaleDown,
    uint256 _usdcCurveTickSize
  ) TieredOwnable(_firstOwner) 
  {
    require(
      _skyweaverAssetsAddress != address(0) && 
      _itemRangeMin < _itemRangeMax,
      "BondingCurveFactory#constructor: INVALID_INPUT"
    );

    // Assets
    usdc = IERC20(_usdc);
    skyweaverAssets = ISkyweaverAssets(_skyweaverAssetsAddress);
    itemRangeMin = _itemRangeMin;
    itemRangeMax = _itemRangeMax;

    // Parameters
    COST_IN_ITEMS = _costInItems;
    USDC_CURVE_CONSTANT = _usdcCurveConstant;    // e.g. 35 * 100
    USDC_CURVE_SCALE_DOWN = _usdcCurveScaleDown; // e.g. 100
    USDC_CURVE_TICK_SIZE = _usdcCurveTickSize;   // e.g. 10 * 100 for increase every 10 mints
  }

  
  /***********************************|
  |      Receiver Method Handler      |
  |__________________________________*/

  /**
   * @notice Prevents receiving Ether or calls to unsuported methods
   */
  fallback () external {
    revert("BondingCurveFactory#_: UNSUPPORTED_METHOD");
  }

  /**
   * @notice Players converting silver cards to conquest entries
   * @dev Payload is passed to and verified by onERC1155BatchReceived()
   */
  function onERC1155Received(
    address _operator,
    address _from,
    uint256 _id, 
    uint256 _amount, 
    bytes calldata _data
  )
    external override returns(bytes4)
  {
    // Convert payload to arrays to pass to onERC1155BatchReceived()
    uint256[] memory ids = new uint256[](1);
    uint256[] memory amounts = new uint256[](1);
    ids[0] = _id;
    amounts[0] = _amount;

    // Will revert call if doesn't pass
    onERC1155BatchReceived(_operator, _from, ids, amounts, _data);
    
    // Return success
    return IERC1155TokenReceiver.onERC1155Received.selector;
  }

  /**
   * @notice Players sending assets to mint
   * @param _ids     An array containing ids of each Token being transferred
   * @param _amounts An array containing amounts of each Token being transferred
   * @param _data    If data is provided, it should be address who will receive the entries
   */
  function onERC1155BatchReceived(
    address, // _operator
    address  _from,
    uint256[] memory _ids,
    uint256[] memory _amounts,
    bytes memory _data
  )
    public override returns(bytes4)
  { 
    require(
      msg.sender == address(skyweaverAssets), 
      "BondingCurveFactory#onERC1155BatchReceived: INVALID_TOKEN_ADDRESS"
    );

    // Decode MintTokenRequest from _data to call _mint()
    MintTokenRequest memory req;
    req = abi.decode(_data, (MintTokenRequest));

    // Calculate cost
    (uint256 costItems, uint256 costUSDC) = getMintingTotalCost(req.itemsBoughtIDs, req.itemsBoughtAmounts);

    // Calculate # of items sent
    uint256 nItemsReceived = _paidItemAmount(_ids, _amounts);

    // Validate payment is sufficient
    require(nItemsReceived == costItems, "BondingCurveFactory#onERC1155BatchReceived: INCORRECT NUMBER OF ITEMS SENT");
    require(costUSDC <= req.maxUSDC, "BondingCurveFactory#onERC1155BatchReceived: MAX USDC EXCEEDED");

    // Transfer USDC to here
    usdc.transferFrom(_from, address(this), costUSDC);

    // Burn items received
    skyweaverAssets.batchBurn(_ids, _amounts);

    // Increase supplies and insure there are no duplicated IDs
    uint256 previousID = 0; // Can't mint id 0, so we use it as first ID
    for (uint256 i = 0; i < req.itemsBoughtIDs.length; i++) {
      uint256 id = req.itemsBoughtIDs[i];
      require(id != 0 && id > previousID, "BondingCurveFactory#onERC1155BatchReceived: UNSORTED itemsBoughtIDs ARRAY OR CONTAIN DUPLICATES");
      mintedAmounts[id] = mintedAmounts[id].add(req.itemsBoughtAmounts[i]);
      previousID = id;
    }

    // Minting assets 
    address recipient = req.recipient == address(0x0) ? _from : req.recipient;
    skyweaverAssets.batchMint(recipient, req.itemsBoughtIDs, req.itemsBoughtAmounts, "");

    // Return success
    return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
  }


  /***********************************|
  |             Payments              |
  |__________________________________*/  

  /**
   * @notice Calculate amount of items sent by user
   * @param _ids      Ids of items sent by user
   * @param _amounts  Amount of each item sent by user
   */
  function _paidItemAmount(uint256[] memory _ids, uint256[] memory _amounts) view internal returns (uint256 nItems) {
    nItems = 0; // Number of valid Items sent

    // Count how many valid items were sent in total
    for (uint256 i = 0; i < _ids.length; i++) {
      require(
        itemRangeMin <= _ids[i] && _ids[i] <= itemRangeMax, 
        "BondingCurveFactory#onERC1155BatchReceived: ID_IS_INVALID"
      );
      nItems = nItems.add(_amounts[i]);
    }

    return nItems;
  }

  /**
   * @notice Get item and usdc cost of all items a minting order
   * @param _ids      Ids of items to mint
   * @param _amounts  Amount of each item to be minted
   */
  function getMintingTotalCost(uint256[] memory _ids, uint256[] memory _amounts) view public returns (uint256 nItems, uint256 nUSDC) {
    // Count how many valid items were sent in total
    uint256 totalAmount = 0;
    for (uint256 i = 0; i < _ids.length; i++) {
      totalAmount = totalAmount.add(_amounts[i]);
    }
    return (totalAmount.mul(COST_IN_ITEMS), usdcTotalCost(_ids, _amounts));
  }

  /**
   * @notice Get item and usdc cost of each item in an order
   * @param _ids      Ids of items to mint
   * @param _amounts  Amount of each item to be minted
   */
  function getMintingCost(uint256[] memory _ids, uint256[] memory _amounts) view public returns (uint256[] memory, uint256[] memory) {
    // Initialize return arrays
    uint256[] memory nItems = new uint256[](_ids.length);
    uint256[] memory nUSDC = new uint256[](_ids.length);

    // Count how many valid items were sent in total
    for (uint256 i = 0; i < _ids.length; i++) {
      nItems[i] =  _amounts[i].mul(COST_IN_ITEMS);
      nUSDC[i] = usdcCost(_ids[i],  _amounts[i]);
    }

    return (nItems, nUSDC);
  }

  /**
   * @notice Returns the cost in USDC, which is based on a bonding curve
   * @param _ids     Ids of items to mint
   * @param _amounts Amount of each item to be minted
   */
  function usdcTotalCost(uint256[] memory _ids, uint256[] memory _amounts) view public returns (uint256 nUSDC) {
    for (uint256 i = 0; i < _ids.length; i++) {
      nUSDC = nUSDC.add(usdcCost(_ids[i], _amounts[i]));
    }
    return nUSDC;
  }

    /**
   * @notice Returns the cost in USDC, which is based on a bonding curve
   * @param _id     ID of item to be minted
   * @param _amount Amount of item to be minted
   */
  function usdcCost(uint256 _id, uint256 _amount) view public returns (uint256 nUSDC) {
    uint256 supply = mintedAmounts[_id];
    uint256 amount = _amount;

    // Go over all the price ticks 
    while (amount > 0) {
      // Check how many can be minted in current tick
      uint256 leftInTick = USDC_CURVE_TICK_SIZE.sub(supply % USDC_CURVE_TICK_SIZE);

      // Check how many will be minted in current tick
      uint256 amountInTick = leftInTick > amount ? amount : leftInTick;

      // Add to the total cost
      nUSDC = nUSDC.add(amountInTick.mul(usdcCurve(supply)));

      // Remove amount to be minted in current tick from total amount
      amount = amount.sub(amountInTick);

      // Increase supply
      supply = supply.add(amountInTick);
    }

    return nUSDC;
  }

  /**
   * @notice Returns value in curve
   * @dev Curve is (x+k)^2 / m
   * @param _x point on the curve, multiple of 100
   */
  function usdcCurve(uint256 _x) view public returns (uint256 nUsdc) {
    // Lower bound of the tick is the price
    // E.g. 1500 will be priced at 1000
    uint256 tickValue = _x.div(USDC_CURVE_TICK_SIZE).mul(USDC_CURVE_TICK_SIZE); 
    // (x+k)^2
    uint256 base = tickValue.add(USDC_CURVE_CONSTANT);
    uint256 exponent = base.mul(base);
    // exponent / m
    return exponent.div(USDC_CURVE_SCALE_DOWN);
  }


  /**
   * @notice Send ERC-20 balance to recipient
   * @param _recipient Address where the currency will be sent to
   * @param _erc20     Address of ERC-20 token to transfer out
   */
  function withdrawERC20(address _recipient, address _erc20) external onlyOwnerTier(HIGHEST_OWNER_TIER) {
    require(_recipient != address(0x0), "BondingCurveFactory#withdrawERC20: INVALID_RECIPIENT");
    uint256 this_balance = IERC20(_erc20).balanceOf(address(this));
    IERC20(_erc20).transfer(_recipient, this_balance);
  }


  /***********************************|
  |         Utility Functions         |
  |__________________________________*/

  /**
   * @notice Indicates whether a contract implements a given interface.
   * @param interfaceID The ERC-165 interface ID that is queried for support.
   * @return True if contract interface is supported.
   */
  function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
    return  interfaceID == type(IERC165).interfaceId || 
      interfaceID == type(IERC1155TokenReceiver).interfaceId;
  }
}