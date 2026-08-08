// A function which takes a string which contains an email address, and obsfucates it.
// The input looks like one of the following (with expected output in parenthesis)::
// - test@example.com (t**t@example.com)
// - test+suffix@example.com (t**t+suffix@example.com)
// - testing test@example.com (testing t**t@example.com)
// - testing testing test+suffix@example.com (testing testing t**t+suffix@example.com)

function obfuscateEmail(input) {
  const obsfucationChar = "*";
  const emailRegex = /([a-z0-9!#$%&'*+\x2f=?^_`\x7b-\x7d~\x2d]+@[^\s]+)/i;

  const email = input.match(emailRegex);
  if (!email) {
    return input;
  }

  // split email part
  const [local, domain] = email[0].split('@', 2);
  // split username part by + to keep intact
  const [username, suffix] = local.split('+', 2);

  let output = "";
  if (username.length < 3) {
    output += obsfucationChar.repeat(username.length);
  } else {
    output += `${username[0]}${obsfucationChar.repeat(username.length - 2)}${username[username.length - 1]}`;
  }

  if (suffix !== undefined) {
    output += `+${suffix}`;
  }
  output += `@${domain}`;

  return input.replace(emailRegex, output);
}

function test_obfuscateEmail() {
  console.log(obfuscateEmail('te@example.com'));
  console.log(obfuscateEmail('test@example.com'));
  console.log(obfuscateEmail('testing@example.com'));
  console.log(obfuscateEmail('test+suffix@example.com'));
  console.log(obfuscateEmail('testing+suffix@example.com'));
  console.log(obfuscateEmail('testing test@example.com'));
  console.log(obfuscateEmail('testing testing@example.com'));
  console.log(obfuscateEmail('testing testing test+suffix@example.com'));
  console.log(obfuscateEmail('testing testing testing+suffix@example.com'));
  console.log(obfuscateEmail('Ben Naylor <nayben@gmail.com>'));
}

test_obfuscateEmail();
