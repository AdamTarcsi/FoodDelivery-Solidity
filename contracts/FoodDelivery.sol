//Write your own contracts here. Currently compiles using solc v0.4.15+commit.bbb8e64f.
pragma solidity ^0.4.24;
import "./Ownable.sol";

/**
 * @title FoodDelivery
 * @dev Barebone smart contract for
 * food delivery decentralized application.
 */
contract FoodDelivery is Ownable {
  mapping (address => uint) private balances;
  mapping (address => uint8) private userTypes;
  mapping (address => string) public restaurantNames;
  mapping (address => uint) public restaurantFoodCount;
  mapping (uint => address) public foodToRestaurant;
  mapping (address => uint) private customerOrderCount;
  mapping (address => uint) private restaurantOrderCount;
  mapping (uint => address) private orderToCustomer;
  mapping (uint => address) private orderToRestaurant;
  mapping (address => uint) public successfulDelivery;

  event NewFood(uint foodId, string name, address restaurant);
  event NewOrder(uint orderId, uint foodId, uint price, address customerAddress, address restaurantAddress);
  event NewCustomer(address customerAddress);
  event NewRestaurant(address restaurantAddress);
  event OrderFinished(uint orderId);

  struct Food {
    string name;
    uint price;
    uint8 avail;
  }

  struct Order {
    uint foodId;
    uint escrowBalance;
    uint8 status; // 0: Order Made | 1: Prepared | 2: Delivered | 3: Cancelled | 4: Divine Intervention
  }

  Food[] public foods;
  Order[] public orders;

  bool public paused = false;

  modifier whenNotPaused() {
      require(!paused);
      _;
   }
  modifier whenPaused() {
      require(paused);
      _;
  }

  modifier onlyRestaurant {
      require(userTypes[msg.sender] == 2);
      _;
  }

  modifier onlyCustomer {
      require(userTypes[msg.sender] == 1);
      _;
  }

  // Fallback function
  function () public {
    revert();
  }

  // External Functions
  // User Registration System
  /* It is intentional that a user can't be both restaurant and a customer.
   * We don't want people to use their business address for personal usage.
   * Similar to why people don't use their business savings for personal expenses.
   */

  /**
   * @dev Allows the user to register their address as a customer.
   */
  function registerCustomer() external whenNotPaused {
      require(userTypes[msg.sender] == 0);
      userTypes[msg.sender] = 1;
      emit NewCustomer(msg.sender);
  }

  /**
   * @dev Allows the user to register their address as a restaurant.
   * @param _restaurantName The name for the new restaurant
   */
  function registerRestaurant(string _restaurantName) external whenNotPaused {
      require(userTypes[msg.sender] == 0 && bytes(_restaurantName).length != 0);
      userTypes[msg.sender] = 2;
      restaurantNames[msg.sender] = _restaurantName;
      emit NewRestaurant(msg.sender);
  }

  /**
   * @dev Allows the user to fetch all foods served by a restaurant.
   * @param _restaurantAddress The address of the restaurant to look for
   */
  function getFoodByRestaurant(address _restaurantAddress) external view returns(uint[]) {
    uint[] memory result = new uint[](restaurantFoodCount[_restaurantAddress]);
    uint counter = 0;
    for (uint i = 0; i < foods.length; i++) {
      if (foodToRestaurant[i] == _restaurantAddress) {
        result[counter] = i;
        counter++;
      }
    }
    return result;
  }

  /**
   * @dev Allows the user to fetch all orders made by a customer.
   * @param _customerAddress The address of the customer to look for
   */
  function getOrderByCustomer(address _customerAddress) external view returns(uint[]) {
    uint[] memory result = new uint[](customerOrderCount[_customerAddress]);
    uint counter = 0;
    for (uint i = 0; i < foods.length; i++) {
      if (orderToCustomer[i] == _customerAddress) {
        result[counter] = i;
        counter++;
      }
    }
    return result;
  }

  /**
   * @dev Allows the user to fetch all orders made for a restaurant.
   * @param _restaurantAddress The address of the restaurant to look for
   */
  function getOrderByRestaurant(address _restaurantAddress) external view returns(uint[]) {
    uint[] memory result = new uint[](restaurantOrderCount[_restaurantAddress]);
    uint counter = 0;
    for (uint i = 0; i < foods.length; i++) {
      if (orderToRestaurant[i] == _restaurantAddress) {
        result[counter] = i;
        counter++;
      }
    }
    return result;
  }

  // !! RESTAURANT ONLY FUNCTIONS !!
  /**
   * @dev Add a new food to the menu.
   * @param _name The name of the new food.
   * @param _price The price of the new food.
   */
  function newFood(string _name, uint _price) external whenNotPaused onlyRestaurant {
      require(bytes(_name).length != 0);
      uint id = foods.push(Food(_name, _price, 1))-1;
      foodToRestaurant[id] = msg.sender;
      restaurantFoodCount[msg.sender]++;
      emit NewFood(id, _name, msg.sender);
  }

  /**
   * @dev Change the price of a food item.
   * @param _foodId The id number of the food item.
   * @param _newPrice The new price for the food item.
   */
  function changePrice(uint _foodId, uint _newPrice) external whenNotPaused onlyRestaurant {
      require(foodToRestaurant[_foodId] == msg.sender);
      foods[_foodId].price = _newPrice;
  }

  /**
   * @dev Set the food item to available.
   * @param _foodId The id number of the food item.
   */
  function soldIn(uint _foodId) external whenNotPaused onlyRestaurant {
      require(foodToRestaurant[_foodId] == msg.sender);
      foods[_foodId].avail = 1;
  }

  /**
   * @dev Set the food item to unavailable.
   * @param _foodId The id number of the food item.
   */
  function soldOut(uint _foodId) external whenNotPaused onlyRestaurant {
      require(foodToRestaurant[_foodId] == msg.sender);
      foods[_foodId].avail = 0;
  }

  /**
   * @dev Set the order status to "Prepared".
   * This prevents user from cancelling their order.
   * @param _orderId The id number of an order.
   */
  function orderPrepared(uint _orderId) external whenNotPaused onlyRestaurant {
      require(orderToRestaurant[_orderId] == msg.sender);
      orders[_orderId].status = 1;
  }

  /**
   * @dev Set the order status to "Cancelled" from the Restaurant side.
   * This function can be used if a condition prevents delivery to be made.
   * @param _orderId The id number of an order.
   */
  function orderUnavailable(uint _orderId) external whenNotPaused onlyRestaurant {
      require(orderToRestaurant[_orderId] == msg.sender && orders[_orderId].status >= 2);
      transferToCustomer(_orderId);
      orders[_orderId].status = 3;
  }

  // !! CUSTOMER ONLY FUNCTIONS !!
  /**
   * @dev Create a new food order.
   * @param _foodId The id number of the food item.
   */
  function newOrder(uint _foodId) external whenNotPaused onlyCustomer {
      require(foods[_foodId].avail == 1);
      uint id = orders.push(Order(_foodId, 0, 0))-1;
      orderToCustomer[id] = msg.sender;
      customerOrderCount[msg.sender]++;
      orderToRestaurant[id] = foodToRestaurant[_foodId];
      restaurantOrderCount[foodToRestaurant[_foodId]]++;
      transferToEscrow(id);
      emit NewOrder(id, _foodId, foods[orders[id].foodId].price, msg.sender, orderToRestaurant[id]);
  }

  /**
   * @dev Cancels an order that the user have made.
   * @param _orderId The id number of an order.
   */
  function cancelOrder(uint _orderId) external whenNotPaused onlyCustomer {
      require(orderToCustomer[_orderId] == msg.sender);
      require(orders[_orderId].status == 0, 'Your order is already prepared, delivered, or cancelled!');
      transferToCustomer(_orderId);
      orders[_orderId].status = 3;
  }

  /**
   * @dev Called to declare that food delivery have been made.
   * @param _orderId The id number of an order.
   */
  function finishOrder(uint _orderId) external whenNotPaused onlyCustomer {
      require(orderToCustomer[_orderId] == msg.sender && orders[_orderId].status == 1);
      transferToRestaurant(_orderId);
      orders[_orderId].status = 2;
      emit OrderFinished(_orderId);

      // For analytics and future implementation
      successfulDelivery[orderToRestaurant[_orderId]] += 1;
  }

  // Public Functions
  // Banking System
  /**
   * @dev Allows the user to deposit their ether into the smart contract.
   * Only customers are allowed to deposit.
   * @return The new balance of user.
   */
  function deposit() public payable whenNotPaused returns (uint) {
      require(userTypes[msg.sender] == 1 && (balances[msg.sender] + msg.value) >= balances[msg.sender]);
      balances[msg.sender] += msg.value;
      return balances[msg.sender];
  }

  /**
   * @dev Allows the user to withdraw their balance
   * @param _withdrawAmount The amount to withdraw
   * @return The new balance of user.
   */
  function withdraw(uint _withdrawAmount) public whenNotPaused returns (uint remainingBal) {
      require(_withdrawAmount <= balances[msg.sender]);
      balances[msg.sender] -= _withdrawAmount;
      msg.sender.transfer(_withdrawAmount); // Automatically reverts state on failure
      return balances[msg.sender];
  }

  /**
   * @dev Allows the user to see their own balance
   * @return The balance of the user.
   */
  function myBalance() constant public returns (uint) {
      require(userTypes[msg.sender] == 1 || userTypes[msg.sender] == 2, 'Register as a user first!');
      return balances[msg.sender];
  }

  /* Private Functions */
  /**
   * @dev Transfer balance frome escrow to customer.
   * @param _orderId The id number of an order.
   */
  function transferToCustomer(uint _orderId) private whenNotPaused {
      require(orders[_orderId].escrowBalance >= 0);
      balances[orderToCustomer[_orderId]] += orders[_orderId].escrowBalance;
      orders[_orderId].escrowBalance = 0;
  }

  /**
   * @dev Transfer balance from escrow to restaurant.
   * @param _orderId The id number of an order.
   */
  function transferToRestaurant(uint _orderId) private whenNotPaused {
      require(orders[_orderId].escrowBalance >= 0);
      balances[orderToRestaurant[_orderId]] += orders[_orderId].escrowBalance;
      orders[_orderId].escrowBalance = 0;
  }

  /**
   * @dev Transfer balance from user to escrow.
   * @param _orderId The id number of an order.
   */
  function transferToEscrow(uint _orderId) private whenNotPaused {
      require(balances[orderToCustomer[_orderId]] >= foods[orders[_orderId].foodId].price);
      require(orders[_orderId].escrowBalance == 0);
      balances[orderToCustomer[_orderId]] -= foods[orders[_orderId].foodId].price;
      orders[_orderId].escrowBalance +=  foods[orders[_orderId].foodId].price;
  }

  /* God Mode Function */
  /**
   * @dev Allows the owner of the smart contract to pause.
   * !! Only to be used during emergency or contract upgrade !!
   */
  function pause() external onlyOwner whenNotPaused {
      paused = true;
  }

  /**
   * @dev Allows the owner of the smart contract to unpause.
   * Intentionally set to public so inherited smart contract can trigger the function.
   */
  function unpause() public onlyOwner {
      paused = false;
  }

  /**
   * @dev Allows the owner of the smart contrac to
   * finish an order in case the customer creates fictious address
   * or didn't want to finish the order after food being delivered.
   * WARN: Bypasses all check.
   * @param _orderId The id number of an order.
   */
  function forceFinishOrder(uint _orderId) external onlyOwner whenNotPaused {
      transferToRestaurant(_orderId);
      orders[_orderId].status = 4;
  }

  /**
   * @dev Allows the owner of the smart contract to
   * cancel an order in case the restaurant didn't deliver
   * their food.
   * WARN: Bypasses all check.
   * @param _orderId The id number of an order.
   */
  function forceCancelOrder(uint _orderId) external onlyOwner whenNotPaused {
      transferToCustomer(_orderId);
      orders[_orderId].status = 4;
  }
}
