const add = require('../src/add');

test('BasicAddition', () => {
  expect(add(2, 3)).toBe(5);
  expect(add(10, 5)).toBe(15);
});
