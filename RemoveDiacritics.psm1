function RemoveDiacritics([System.String] $text)
{

if ([System.String]::IsNullOrEmpty($text))
{
    return text;
}


    $Normalized = $text.Normalize([System.Text.NormalizationForm]::FormD)
    $NewString = New-Object -TypeName System.Text.StringBuilder

    $normalized.ToCharArray() | ForEach{
            if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($psitem) -ne [Globalization.UnicodeCategory]::NonSpacingMark)
            {
                [void]$NewString.Append($psitem)
            }
        }

    return $NewString.ToString()
    
}