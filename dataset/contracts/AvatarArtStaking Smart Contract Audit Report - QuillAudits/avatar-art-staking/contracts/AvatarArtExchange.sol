// SPDX-License-Identifier: MIT

import "./interfaces/IERC20.sol";
import "./interfaces/IAvatarArtExchange.sol";
import "./core/Runnable.sol";

pragma solidity ^0.8.0;

contract AvatarArtOrderBook is Runnable, IAvatarArtExchange{
    enum EOrderType{
        Buy, 
        Sell
    }
    
    enum EOrderStatus{
        Open,
        Filled,
        Canceled
    }
    
    struct Order{
        uint256 orderId;
        address owner;
        uint256 price;
        uint256 quantity;
        uint256 filledQuantity;
        uint256 time;
        EOrderStatus status;
        uint256 fee;
    }
    
    struct FilledHistory{
        uint256 buyOrderId;
        uint256 sellOrderId;
        uint256 price;
        uint256 quantity;
    }
    
    uint256 constant public MULTIPLIER = 1000;
    
    //Address of contract that will generate token for specific NFT
    address private _generatorAddress;
    IERC20 private _bnuToken;
    
    uint256 private _fee;
    uint256 private _buyOrderIndex = 1;
    uint256 private _sellOrderIndex = 1;
    
    //Checks whether an `itemAddress` can be tradable or not
    mapping(address => bool) private _isTradableItems;
    
    //Stores users' orders for trading
    mapping(address => Order[]) private _buyOrders;
    mapping(address => Order[]) private _sellOrders;
    
    mapping(address => FilledHistory[]) private _filledHistories;
    
    function getBnuToken() public view returns(IERC20){
        return _bnuToken;
    }
    
    function getFee() public view returns(uint256){
        return _fee;
    }
    
    function getGeneratorAddress() public view returns(address){
        return _generatorAddress;
    }
    
    /**
     * @dev Get all open orders by `itemAddress`
     */ 
    function getOpenOrders(address itemAddress, EOrderType orderType) public view returns(Order[] memory){
        Order[] memory orders;
        if(orderType == EOrderType.Buy)
            orders = _buyOrders[itemAddress];
        else
            orders = _sellOrders[itemAddress];
        if(orders.length == 0)
            return orders;
        
        uint256 count = 0;
        Order[] memory tempOrders = new Order[](orders.length);
        for(uint256 index = 0; index < orders.length; index++){
            Order memory order = orders[index];
            if(order.status == EOrderStatus.Open){
                tempOrders[count] = order;
                count++;
            }
        }
        
        Order[] memory result = new Order[](count);
        for(uint256 index = 0; index < count; index++){
            result[index] = tempOrders[index];
        }
        
        return result;
    }
    
    /**
     * @dev Get buying orders that can be filled with `price` of `itemAddress`
     */ 
    function getOpenBuyOrdersForPrice(address itemAddress, uint256 price) public view returns(Order[] memory){
        Order[] memory orders = _buyOrders[itemAddress];
        if(orders.length == 0)
            return orders;
        
        uint256 count = 0;
        Order[] memory tempOrders = new Order[](orders.length);
        for(uint256 index = 0; index < orders.length; index++){
            Order memory order = orders[index];
            if(order.status == EOrderStatus.Open && order.price >= price){
                tempOrders[count] = order;
                count++;
            }
        }
        
        Order[] memory result = new Order[](count);
        for(uint256 index = 0; index < count; index++){
            result[index] = tempOrders[index];
        }
        
        return result;
    }
    
    function getOrders(address itemAddress, EOrderType orderType) public view returns(Order[] memory){
        return orderType == EOrderType.Buy ? _buyOrders[itemAddress] : _sellOrders[itemAddress];
    }
    
    function getUserOrders(address itemAddress, address account, EOrderType orderType) public view returns(Order[] memory){
        Order[] memory orders;
        if(orderType == EOrderType.Buy)
            orders = _buyOrders[itemAddress];
        else
            orders = _sellOrders[itemAddress];
        if(orders.length == 0)
            return orders;
        
        uint256 count = 0;
        Order[] memory tempOrders = new Order[](orders.length);
        for(uint256 index = 0; index < orders.length; index++){
            Order memory order = orders[index];
            if(order.owner == account){
                tempOrders[count] = order;
                count++;
            }
        }
        
        Order[] memory result = new Order[](count);
        for(uint256 index = 0; index < count; index++){
            result[index] = tempOrders[index];
        }
        
        return result;
    }
    
    /**
     * @dev Get selling orders that can be filled with `price` of `itemAddress`
     */ 
    function getOpenSellOrdersForPrice(address itemAddress, uint256 price) public view returns(Order[] memory){
        Order[] memory orders = _sellOrders[itemAddress];
        if(orders.length == 0)
            return orders;
        
        uint256 count = 0;
        Order[] memory tempOrders = new Order[](orders.length);
        for(uint256 index = 0; index < orders.length; index++){
            Order memory order = orders[index];
            if(order.status == EOrderStatus.Open && order.price <= price){
                tempOrders[count] = order;
                count++;
            }
        }
        
        Order[] memory result = new Order[](count);
        for(uint256 index = 0; index < count; index++){
            result[index] = tempOrders[index];
        }
        
        return result;
    }
    
    function getFilledHistories(address itemAddress) public view returns(FilledHistory[] memory){
        return _filledHistories[itemAddress];
    }
    
    function isTradable(address itemAddress) public view returns(bool){
        return _isTradableItems[itemAddress];
    }
    
    function setBnuToken(address newAddress) public onlyOwner{
        require(newAddress != address(0),"Zero address");
        _bnuToken = IERC20(newAddress);
    }
    
    function setFee(uint256 fee) public onlyOwner{
        _fee = fee;
    }
    
    function setGeneratorAddress(address newAddress) public onlyOwner{
        require(newAddress != address(0),"Zero address");
        _generatorAddress = newAddress;
    }
    
   /**
     * @dev Allow or disallow `itemAddress` to be traded on AvatarArtOrderBook
    */
    function toogleTradableStatus(address itemAddress) public override onlyOwner returns(bool){
        _isTradableItems[itemAddress] = !isTradable(itemAddress);
        
        return true;
    }
    
    /**
     * @dev See {IAvatarArtOrderBook.buy}
     * 
     * IMPLEMENTATION
     *    1. Validate requirements
     *    2. Process buy order 
     */ 
    function buy(address itemAddress, uint256 price, uint256 quantity) public override isRunning returns(bool){
        require(isTradable(itemAddress), "Can not tradable");
        require(price > 0 && quantity > 0, "Zero input");
        
        uint256 matchedQuantity = 0;
        uint256 needToMatchedQuantity = quantity;
        
        Order memory order = Order({
            orderId: _buyOrderIndex,
            owner: _msgSender(),
            price: price,
            quantity: quantity,
            filledQuantity: 0,
            time: _now(),
            fee: _fee,
            status: EOrderStatus.Open
        });
        
        uint256 totalPaidAmount = 0;
        
        //Get all open sell orders that are suitable for `price`
        Order[] memory matchedOrders = getOpenSellOrdersForPrice(itemAddress, price);
        if (matchedOrders.length > 0){
            matchedQuantity = 0;
            uint256 changePrice = 0;
            for(uint256 index = 0; index < matchedOrders.length; index++)
            {
                Order memory matchedOrder = matchedOrders[index];
                uint256 matchedOrderRemainQuantity = matchedOrder.quantity - matchedOrder.filledQuantity;
                uint256 currentFilledQuantity = 0;
                if (needToMatchedQuantity < matchedOrderRemainQuantity)     //Filled
                {
                    matchedQuantity = quantity;
                    
                    //Update matchedOrder matched quantity
                    _increaseFilledQuantity(itemAddress, EOrderType.Sell, matchedOrder.orderId, needToMatchedQuantity);
                    
                    currentFilledQuantity = needToMatchedQuantity;
                    needToMatchedQuantity = 0;
                }
                else
                {
                    matchedQuantity += matchedOrderRemainQuantity;
                    needToMatchedQuantity -= matchedOrderRemainQuantity;
                    currentFilledQuantity = matchedOrderRemainQuantity;

                    //Update matchedOrder to completed
                    _updateOrderToBeFilled(itemAddress, matchedOrder.orderId, EOrderType.Sell);
                }

                if (matchedOrder.price != changePrice)
                {
                    changePrice = matchedOrder.price;
                    emit PriceChanged(itemAddress, changePrice, _now());
                }

                totalPaidAmount += currentFilledQuantity * matchedOrder.price;
                
                //Create matched order
                _filledHistories[itemAddress].push(FilledHistory({
                        buyOrderId: order.orderId,
                        sellOrderId: matchedOrder.orderId,
                        price: matchedOrder.price,
                        quantity: currentFilledQuantity}));

                //Increase buy user ticker 1 balance
                IERC20(itemAddress).transfer(_msgSender(), currentFilledQuantity * (1 - _fee / 100 / MULTIPLIER));

                //Increase sell user ticker2 balance
                _bnuToken.transfer(matchedOrder.owner, currentFilledQuantity * matchedOrder.price * (1 - matchedOrder.fee / 100 / MULTIPLIER));

                emit RefreshUserOrders(itemAddress, matchedOrder.owner);
                
                if (needToMatchedQuantity == 0)
                    break;
            }
        }

        totalPaidAmount += price * (quantity - matchedQuantity);
        if(totalPaidAmount > 0)
            _bnuToken.transferFrom(_msgSender(), address(this), totalPaidAmount);

        //Create order
        order.filledQuantity = matchedQuantity;
        if(order.filledQuantity != quantity)
            order.status = EOrderStatus.Open;
        else
            order.status = EOrderStatus.Filled;
        _buyOrders[itemAddress].push(order);
        
        emit RefreshUserOrders(itemAddress, _msgSender());
        
        //Event for all user to refresh buy order
        emit RefreshOpenOrders(itemAddress, EOrderType.Buy);
        
        //If has matchedOrders, emit event for refresh sell order
        if (matchedOrders.length > 0)
            emit RefreshOpenOrders(itemAddress, EOrderType.Sell);
        
        _buyOrderIndex++;
        emit OrderCreated(_now(), _msgSender(), itemAddress, EOrderType.Buy, price, quantity);
        return true;
    }
    
    /**
     * @dev Sell `itemAddress` with `price` and `amount`
     */ 
    function sell(address itemAddress, uint256 price, uint256 quantity) public override isRunning returns(bool){
        require(isTradable(itemAddress), "Can not tradable");
        require(price > 0 && quantity > 0, "Zero input");
        
        uint256 matchedQuantity = 0;
        uint256 needToMatchedQuantity = quantity;

        Order memory order = Order({
            orderId: _sellOrderIndex,
            owner: _msgSender(),
            price: price,
            quantity: quantity,
            filledQuantity: 0,
            time: _now(),
            fee: _fee,
            status: EOrderStatus.Open
        });
        
        IERC20(itemAddress).transferFrom(_msgSender(), address(this), quantity);
        Order[] memory matchedOrders = getOpenBuyOrdersForPrice(itemAddress, price);
        if (matchedOrders.length > 0){
            matchedQuantity = 0;
            uint256 changedPrice = 0;
            for(uint index = 0; index < matchedOrders.length; index++)
            {
                Order memory matchedOrder = matchedOrders[index];
                uint256 matchedOrderRemainQuantity = matchedOrder.quantity - matchedOrder.filledQuantity;
                uint256 currentMatchedQuantity = 0;
                if (needToMatchedQuantity < matchedOrderRemainQuantity)     //Filled
                {
                    matchedQuantity = quantity;
                    
                     //Update matchedOrder matched quantity
                    _increaseFilledQuantity(itemAddress, EOrderType.Buy, matchedOrder.orderId, needToMatchedQuantity);

                    currentMatchedQuantity = needToMatchedQuantity;
                    needToMatchedQuantity = 0;
                }
                else
                {
                    matchedQuantity += matchedOrderRemainQuantity;
                    needToMatchedQuantity -= matchedOrderRemainQuantity;
                    currentMatchedQuantity = matchedOrderRemainQuantity;

                    //Update matchedOrder to completed
                    _updateOrderToBeFilled(itemAddress, matchedOrder.orderId, EOrderType.Buy);
                }
                
                 //Create matched order
                _filledHistories[itemAddress].push(FilledHistory({
                    buyOrderId: matchedOrder.orderId,
                    sellOrderId: order.orderId,
                    price: matchedOrder.price,
                    quantity: currentMatchedQuantity
                }));
               
                if (matchedOrder.price != changedPrice)
                    emit PriceChanged(itemAddress, changedPrice, _now());

                //Increase buy user ticker 1 balance
                IERC20(itemAddress).transfer(matchedOrder.owner, currentMatchedQuantity * (1 - matchedOrder.fee / 100 / MULTIPLIER));

                //Increase sell user ticker2 balance
                _bnuToken.transfer(_msgSender(), currentMatchedQuantity * matchedOrder.price * (1 - _fee / 100 / MULTIPLIER));

                emit RefreshUserOrders(itemAddress, matchedOrder.owner);

                if (needToMatchedQuantity == 0)
                    break;
            }
        }

        order.filledQuantity = matchedQuantity;
        if(order.filledQuantity != quantity)
            order.status = EOrderStatus.Open;
        else
            order.status = EOrderStatus.Filled;
       
        _sellOrders[itemAddress].push(order);
        
        emit RefreshUserOrders(itemAddress, _msgSender());
        
        //Event for all user to refresh buy order
        emit RefreshOpenOrders(itemAddress, EOrderType.Sell);
        
        //If has matchedOrders, emit event for refresh sell order
        if (matchedOrders.length > 0)
            emit RefreshOpenOrders(itemAddress, EOrderType.Buy);

        _sellOrderIndex++;
        emit OrderCreated(_now(), _msgSender(), itemAddress, EOrderType.Sell, price, quantity);
        return true;
    }
    
    /**
     * @dev Cancel an open trading order for `itemAddress` by `orderId`
     */ 
    function cancel(address itemAddress, uint256 orderId, uint256 orderType) public override isRunning returns(bool){
        EOrderType eOrderType = EOrderType(orderType);
        require(eOrderType == EOrderType.Buy || eOrderType == EOrderType.Sell,"Invalid order type");
        
        if(eOrderType == EOrderType.Buy)
            return _cancelBuyOrder(itemAddress, orderId);
        else
            return _cancelSellOrder(itemAddress, orderId);
    }
    
    /**
     * @dev Cancel buy order
     */ 
    function _cancelBuyOrder(address itemAddress, uint256 orderId) internal returns(bool){
        for(uint256 index = 0; index < _buyOrders[itemAddress].length; index++){
            Order storage order = _buyOrders[itemAddress][index];
            if(order.orderId == orderId){
                if(order.status != EOrderStatus.Open)
                    revert("Order is not open");
                
                order.status = EOrderStatus.Canceled;
                _bnuToken.transfer(order.owner, (order.quantity - order.filledQuantity) * order.price);
                break;
            }
        }
        return true;
    }
    
    /**
     * @dev Cancel sell order
     */ 
    function _cancelSellOrder(address itemAddress, uint256 orderId) internal returns(bool){
        for(uint256 index = 0; index < _sellOrders[itemAddress].length; index++){
            Order storage order = _sellOrders[itemAddress][index];
            if(order.orderId == orderId){
                if(order.status != EOrderStatus.Open)
                    revert("Order is not open");
                
                order.status = EOrderStatus.Canceled;
                IERC20(itemAddress).transfer(order.owner, order.quantity - order.filledQuantity);
                break;
            }
        }
        return true;
    }
    
    /**
     * @dev Increase filled quantity of specific order
     */ 
    function _increaseFilledQuantity(address itemAddress, EOrderType orderType, uint256 orderId, uint256 quantity) internal {
        if(orderType == EOrderType.Buy){
            for(uint256 index = 0; index < _buyOrders[itemAddress].length; index++){
                Order storage order = _buyOrders[itemAddress][index];
                if(order.orderId == orderId){
                    order.filledQuantity += quantity;
                    break;
                }
            }
        }else{
            for(uint256 index = 0; index < _sellOrders[itemAddress].length; index++){
                Order storage order = _buyOrders[itemAddress][index];
                if(order.orderId == orderId){
                    order.filledQuantity += quantity;
                    break;
                }
            }
        }
    }
    
    /**
     * @dev Update the order is filled all
     */ 
    function _updateOrderToBeFilled(address itemAddress, uint256 orderId, EOrderType orderType) internal{
        if(orderType == EOrderType.Buy){
            for(uint256 index = 0; index < _buyOrders[itemAddress].length; index++){
                Order storage order = _buyOrders[itemAddress][index];
                if(order.orderId == orderId){
                    order.filledQuantity == order.quantity;
                    order.status = EOrderStatus.Filled;
                    break;
                }
            }
        }else{
            for(uint256 index = 0; index < _sellOrders[itemAddress].length; index++){
                Order storage order = _buyOrders[itemAddress][index];
                if(order.orderId == orderId){
                    order.filledQuantity == order.quantity;
                    order.status = EOrderStatus.Filled;
                    break;
                }
            }
        }
    }
    
    event OrderCreated(uint256 time, address indexed account, address itemAddress, EOrderType orderType, uint256 price, uint256 quantity);
    event PriceChanged(address itemAddress, uint256 price, uint256 time);
    event RefreshUserOrders(address itemAddress, address account);
    event RefreshOpenOrders(address itemAddress, EOrderType orderType);
}