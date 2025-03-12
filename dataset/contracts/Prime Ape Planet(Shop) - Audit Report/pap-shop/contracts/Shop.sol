//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;

import "./IShop.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract Shop is IShop, Initializable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant SHOP_ADMIN_ROLE = keccak256("SHOP_ADMIN_ROLE");

    IERC20Upgradeable private _token;
    address private _recipient;

    uint256[] private _itemIds;
    mapping(uint256 => Item) private _items;

    // user -> itemId -> count
    mapping(address => mapping(uint256 => uint256)) _userItemCount;

    function initialize(
        address shopAdmin,
        IERC20Upgradeable token,
        address recipient
    ) external initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SHOP_ADMIN_ROLE, shopAdmin);

        _token = token;
        _recipient = recipient;
    }

    // ------ SHOP_ADMIN_ROLE functions -------- //

    function addItem(
        uint256 scSaleId,
        uint256 price,
        uint256 totalQuantity,
        uint256 maxPerUser,
        bool active
    ) external onlyRole(SHOP_ADMIN_ROLE) {
        Item storage item = _items[scSaleId];

        require(item.price == 0, "Item for this scSaleId already exists");
        require(
            price > 0 && totalQuantity > 0 && maxPerUser > 0,
            "Price, totalQuantity and maxPerUser must be greater than 0"
        );

        item.price = price;
        item.totalQuantity = totalQuantity;
        item.maxPerUser = maxPerUser;
        item.active = active;

        _itemIds.push(scSaleId);

        emit ItemChanged(
            scSaleId,
            item.price,
            item.totalQuantity,
            item.maxPerUser,
            item.active
        );
    }

    function editItem(
        uint256 scSaleId,
        uint256 price,
        uint256 totalQuantity,
        uint256 maxPerUser,
        bool active
    ) external onlyRole(SHOP_ADMIN_ROLE) {
        Item storage item = _getItem(scSaleId);

        require(
            price > 0 && totalQuantity > 0 && maxPerUser > 0,
            "Price, totalQuantity and maxPerUser must be greater than 0"
        );
        require(
            totalQuantity >= item.totalQuantity,
            "Cannot reduce totalQuantity"
        );

        item.price = price;
        item.totalQuantity = totalQuantity;
        item.maxPerUser = maxPerUser;
        item.active = active;

        emit ItemChanged(
            scSaleId,
            item.price,
            item.totalQuantity,
            item.maxPerUser,
            item.active
        );
    }

    function changeStatus(uint256 scSaleId, bool active)
        external
        onlyRole(SHOP_ADMIN_ROLE)
    {
        Item storage item = _getItem(scSaleId);

        item.active = active;

        emit ItemChanged(
            scSaleId,
            item.price,
            item.totalQuantity,
            item.maxPerUser,
            item.active
        );
    }

    // ------- PUBLIC FUNCTIONS ----- //

    function buy(uint256 scSaleId) external {
        Item storage item = _getItem(scSaleId);

        require(item.active, "Item is not active");
        require(item.totalQuantity > item.sold, "No more item in stock");
        require(
            item.maxPerUser > _userItemCount[msg.sender][scSaleId],
            "Max per user reached"
        );

        item.sold++;
        _userItemCount[msg.sender][scSaleId]++;
        _token.safeTransferFrom(msg.sender, _recipient, item.price);

        emit Order(msg.sender, scSaleId, item.price, block.timestamp);
    }

    function getItem(uint256 scSaleId) external view returns (Item memory) {
        return _getItem(scSaleId);
    }

    function getActiveItems() external view returns (ActiveItem[] memory) {
        uint256 activeCount;
        for (uint256 i = 0; i < _itemIds.length; i++) {
            Item memory item = _items[_itemIds[i]];
            if (item.active && item.sold < item.totalQuantity) {
                activeCount++;
            }
        }

        uint256 activeItemIdx;
        ActiveItem[] memory activeItems = new ActiveItem[](activeCount);

        for (uint256 i = 0; i < _itemIds.length; i++) {
            Item memory item = _items[_itemIds[i]];
            if (item.active && item.sold < item.totalQuantity) {
                activeItems[activeItemIdx++] = ActiveItem(
                    _itemIds[i],
                    item.price,
                    item.totalQuantity,
                    item.maxPerUser,
                    item.sold
                );
            }
        }

        return activeItems;
    }

    // ------- HELPERS ------- //

    function _getItem(uint256 scSaleId) internal view returns (Item storage) {
        require(
            _items[scSaleId].price > 0,
            "Item with this scSaleId not found"
        );

        return _items[scSaleId];
    }
}
