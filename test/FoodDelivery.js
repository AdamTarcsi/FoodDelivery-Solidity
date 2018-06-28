const FoodDelivery = artifacts.require("./FoodDelivery.sol");

contract('Food Delivery Test', function([owner, restaurant, customer]) {


  it('has an owner', async function() {
    let instance = await FoodDelivery.deployed(owner)

    assert.equal(await instance.owner(), owner)
  })

  it('registered as a restaurant', async function() {
    let instance = await FoodDelivery.deployed(owner)

    instance.registerRestaurant("Pizza Shop", {
      from: restaurant
    })
    let userTypes = await instance.myUserType.call({
      from: restaurant
    })
    assert.equal(userTypes.valueOf(), 2)
  })

  it('create new food', async function() {
    let instance = await FoodDelivery.deployed(owner)

    let foodId = await instance.newFood.call("Pizza", 1, {
      from: restaurant
    })
    await instance.newFood("pizza", 1, {
      from: restaurant
    })
    assert.equal(foodId.c[0], 0)
  })

  it('registered as customer', async function() {
    let instance = await FoodDelivery.deployed(owner)

    await instance.registerCustomer({
      from: customer
    })
    let userTypes = await instance.myUserType.call({
      from: customer
    })
    assert.equal(userTypes.valueOf(), 1)
  })

  it('customer banking system working properly', async function() {
    let instance = await FoodDelivery.deployed(owner)

    await instance.deposit({
      value: 10,
      from: customer
    })
    let balance = await instance.myBalance({
      from: customer
    })
    assert.equal(balance.valueOf(), 10)

    await instance.withdraw(10, {
      from: customer
    })
    balance = await instance.myBalance({
      from: customer
    })
    assert.equal(balance.valueOf(), 0)

    await instance.deposit({
      value: 10,
      from: customer
    })
    balance = await instance.myBalance({
      from: customer
    })
    assert.equal(balance.valueOf(), 10)
  })

  it('create new order', async function() {
    let instance = await FoodDelivery.deployed(owner)

    let orderId = await instance.newOrder.call(0, {
      from: customer
    })
    orderId = orderId.c[0]

    await instance.newOrder(0, {
      from: customer
    })

    let whoRestaurant = await instance.orderToRestaurant.call(0)
    let whoCustomer = await instance.orderToCustomer.call(0)
    let customerBalance = await instance.myBalance.call({
      from: customer
    })

    assert.equal(orderId.valueOf(), 0)
    assert.equal(whoRestaurant, restaurant)
    assert.equal(whoCustomer, customer)
    assert.equal(customerBalance.valueOf(), 9)
  })

  it('set order to prepared', async function() {
    let instance = await FoodDelivery.deployed(owner)
    let orderId = 0

    await instance.orderPrepared(orderId, {
      from: restaurant
    })
    let orderStatus = await instance.myOrderStatus.call(orderId, {
      from: restaurant
    })
    assert.equal(orderStatus.valueOf(), 1)
  })

  it('set order to delivered', async function() {
    let instance = await FoodDelivery.deployed(owner)
    let orderId = 0

    await instance.finishOrder(orderId, {
      from: customer
    })
    let orderStatus = await instance.myOrderStatus.call(orderId, {
      from: restaurant
    })
    assert.equal(orderStatus.valueOf(), 2)
  })

  it('money received by restaurant', async function() {
    let instance = await FoodDelivery.deployed(owner)

    let restaurantBalance = await instance.myBalance({
      from: restaurant
    })
    assert.equal(restaurantBalance.valueOf(), 1)
  })

})
