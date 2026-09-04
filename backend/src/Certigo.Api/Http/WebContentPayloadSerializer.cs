using Certigo.Application.Abstractions;

namespace Certigo.Api.Http;

public sealed class WebContentPayloadSerializer : IContentPayloadSerializer
{
    public byte[] Serialize<T>(T value) => HttpExtensions.SerializeJsonBytes(value);
}
