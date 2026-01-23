package br.com.dito.ditosdk.utils;

import com.google.common.truth.Truth;
import org.junit.Test;
import java.security.NoSuchAlgorithmException;
import java.io.UnsupportedEncodingException;

import static br.com.dito.ditosdk.utils.DitoSDKUtils.SHA1;

public class DitoSDKUtilsTest {

    @Test
    public void SHA1_shouldReturnCorrectHash() throws NoSuchAlgorithmException, UnsupportedEncodingException {
        String input = "test";
        String hash = SHA1(input);

        Truth.assertThat(hash).isNotEmpty();
        Truth.assertThat(hash.length()).isEqualTo(40);
        Truth.assertThat(hash).matches("[0-9a-f]{40}");
    }

    @Test
    public void SHA1_shouldReturnConsistentHash() throws NoSuchAlgorithmException, UnsupportedEncodingException {
        String input = "consistent";
        String hash1 = SHA1(input);
        String hash2 = SHA1(input);

        Truth.assertThat(hash1).isEqualTo(hash2);
    }

    @Test
    public void SHA1_shouldReturnDifferentHashForDifferentInputs() throws NoSuchAlgorithmException, UnsupportedEncodingException {
        String input1 = "test1";
        String input2 = "test2";

        String hash1 = SHA1(input1);
        String hash2 = SHA1(input2);

        Truth.assertThat(hash1).isNotEqualTo(hash2);
    }

    @Test
    public void SHA1_shouldHandleEmptyString() throws NoSuchAlgorithmException, UnsupportedEncodingException {
        String hash = SHA1("");

        Truth.assertThat(hash).isNotEmpty();
        Truth.assertThat(hash.length()).isEqualTo(40);
    }

    @Test
    public void SHA1_shouldHandleSpecialCharacters() throws NoSuchAlgorithmException, UnsupportedEncodingException {
        String input = "test@123#special";
        String hash = SHA1(input);

        Truth.assertThat(hash).isNotEmpty();
        Truth.assertThat(hash.length()).isEqualTo(40);
    }
}
